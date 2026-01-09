#include "tp_internal.h"
#include <stdio.h>
#include <string.h>

tp_err_t tp_producer_send_metadata_announce(
    tp_producer_t *producer,
    uint32_t meta_version,
    const char *name,
    const char *summary);

tp_err_t tp_producer_send_metadata_meta(
    tp_producer_t *producer,
    uint32_t meta_version,
    uint64_t timestamp_ns,
    const tp_metadata_attribute_t *attrs,
    uint32_t attr_count);

static bool tp_is_power_of_two(uint32_t value)
{
    return value != 0 && (value & (value - 1)) == 0;
}

static tp_err_t tp_init_producer_from_attach(tp_client_t *client, const tp_attach_response_t *resp, tp_producer_t **out)
{
    tp_producer_t *producer = (tp_producer_t *)calloc(1, sizeof(tp_producer_t));
    if (producer == NULL)
    {
        return TP_ERR_NOMEM;
    }
    producer->client = client;
    producer->lease_id = resp->lease_id;
    producer->stream_id = resp->stream_id;
    producer->epoch = resp->epoch;
    producer->layout_version = resp->layout_version;
    producer->header_nslots = resp->header_nslots;
    producer->header_slot_bytes = resp->header_slot_bytes;
    producer->pool_count = resp->pool_count;
    producer->metadata_version = 0;
    producer->metadata_attr_count = 0;
    producer->metadata_dirty = false;
    producer->metadata_name[0] = '\0';
    producer->metadata_summary[0] = '\0';
    if (!tp_is_power_of_two(resp->header_nslots))
    {
        tp_producer_close(producer);
        return TP_ERR_PROTOCOL;
    }

    bool require_hugepages = false;
    if (tp_shm_validate_uri(resp->header_uri, &require_hugepages) != TP_OK)
    {
        tp_producer_close(producer);
        return TP_ERR_PROTOCOL;
    }
    if (require_hugepages)
    {
        tp_producer_close(producer);
        return TP_ERR_UNSUPPORTED;
    }

    size_t header_size = TP_SUPERBLOCK_SIZE + (size_t)resp->header_nslots * resp->header_slot_bytes;
    if (tp_shm_map(resp->header_uri, header_size, true, &producer->header) != TP_OK)
    {
        tp_producer_close(producer);
        return TP_ERR_SHM;
    }
    if (tp_shm_validate_superblock(
            &producer->header,
            resp->layout_version,
            resp->epoch,
            resp->stream_id,
            resp->header_nslots,
            resp->header_slot_bytes,
            0,
            0,
            shm_tensorpool_control_regionType_HEADER_RING) != TP_OK)
    {
        tp_producer_close(producer);
        return TP_ERR_PROTOCOL;
    }

    for (uint32_t i = 0; i < resp->pool_count; i++)
    {
        require_hugepages = false;
        if (tp_shm_validate_uri(resp->pools[i].uri, &require_hugepages) != TP_OK)
        {
            tp_producer_close(producer);
            return TP_ERR_PROTOCOL;
        }
        if (tp_validate_stride_bytes(resp->pools[i].stride_bytes, require_hugepages) != TP_OK)
        {
            tp_producer_close(producer);
            return TP_ERR_PROTOCOL;
        }
        producer->pools[i].pool_id = resp->pools[i].pool_id;
        producer->pools[i].nslots = resp->pools[i].nslots;
        producer->pools[i].stride_bytes = resp->pools[i].stride_bytes;
        size_t pool_size = TP_SUPERBLOCK_SIZE + (size_t)resp->pools[i].nslots * resp->pools[i].stride_bytes;
        if (tp_shm_map(resp->pools[i].uri, pool_size, true, &producer->pools[i].mapping) != TP_OK)
        {
            tp_producer_close(producer);
            return TP_ERR_SHM;
        }
        if (tp_shm_validate_superblock(
                &producer->pools[i].mapping,
                resp->layout_version,
                resp->epoch,
                resp->stream_id,
                resp->pools[i].nslots,
                resp->pools[i].stride_bytes,
                resp->pools[i].stride_bytes,
                resp->pools[i].pool_id,
                shm_tensorpool_control_regionType_PAYLOAD_POOL) != TP_OK)
        {
            tp_producer_close(producer);
            return TP_ERR_PROTOCOL;
        }
    }

    if (tp_add_publication(client->aeron, client->context->descriptor_channel, client->context->descriptor_stream_id, &producer->pub_descriptor) < 0)
    {
        tp_producer_close(producer);
        return TP_ERR_AERON;
    }
    if (client->context->metadata_channel[0] != '\0' && client->context->metadata_stream_id != 0)
    {
        if (tp_add_publication(client->aeron, client->context->metadata_channel, client->context->metadata_stream_id, &producer->pub_metadata) < 0)
        {
            tp_producer_close(producer);
            return TP_ERR_AERON;
        }
    }
    if (client->context->qos_channel[0] != '\0' && client->context->qos_stream_id != 0)
    {
        if (tp_add_publication(client->aeron, client->context->qos_channel, client->context->qos_stream_id, &producer->pub_qos) < 0)
        {
            tp_producer_close(producer);
            return TP_ERR_AERON;
        }
    }

    producer->last_qos_ns = tp_now_ns();
    producer->last_keepalive_ns = producer->last_qos_ns;
    *out = producer;
    return TP_OK;
}

tp_err_t tp_attach_producer(tp_client_t *client, uint32_t stream_id, tp_producer_t **producer)
{
    if ((client == NULL) || (producer == NULL))
    {
        return TP_ERR_ARG;
    }
    tp_err_t err = tp_send_attach_request(client, stream_id, shm_tensorpool_driver_role_PRODUCER, shm_tensorpool_driver_publishMode_EXISTING_OR_CREATE);
    if (err != TP_OK)
    {
        return err;
    }

    tp_attach_response_t resp;
    err = tp_wait_attach(client, client->driver.pending_attach_correlation, &resp);
    if (err != TP_OK)
    {
        const char *debug_env = getenv("TP_DEBUG_ATTACH");
        if (debug_env != NULL && debug_env[0] != '\0')
        {
            fprintf(stderr, "tp_attach_producer: wait_attach failed (err=%d)\n", err);
        }
        return err;
    }
    if (resp.code != shm_tensorpool_driver_responseCode_OK)
    {
        const char *debug_env = getenv("TP_DEBUG_ATTACH");
        if (debug_env != NULL && debug_env[0] != '\0')
        {
            fprintf(stderr,
                "tp_attach_producer: attach rejected (code=%d, error=%s)\n",
                resp.code,
                resp.error_message);
        }
        return TP_ERR_PROTOCOL;
    }
    if (resp.stream_id != stream_id)
    {
        return TP_ERR_PROTOCOL;
    }
    return tp_init_producer_from_attach(client, &resp, producer);
}

tp_err_t tp_producer_reattach(tp_producer_t **producer)
{
    if ((producer == NULL) || (*producer == NULL))
    {
        return TP_ERR_ARG;
    }
    tp_client_t *client = (*producer)->client;
    uint32_t stream_id = (*producer)->stream_id;
    tp_producer_close(*producer);
    *producer = NULL;
    return tp_attach_producer(client, stream_id, producer);
}

static tp_pool_mapping_t *tp_find_pool(tp_producer_t *producer, uint16_t pool_id)
{
    for (uint32_t i = 0; i < producer->pool_count; i++)
    {
        if (producer->pools[i].pool_id == pool_id)
        {
            return &producer->pools[i];
        }
    }
    return NULL;
}

static tp_pool_mapping_t *tp_select_pool(tp_producer_t *producer, uint32_t values_len)
{
    tp_pool_mapping_t *best = NULL;
    uint32_t best_stride = UINT32_MAX;
    for (uint32_t i = 0; i < producer->pool_count; i++)
    {
        uint32_t stride = producer->pools[i].stride_bytes;
        if (stride >= values_len && stride < best_stride)
        {
            best = &producer->pools[i];
            best_stride = stride;
        }
    }
    return best;
}

tp_err_t tp_producer_try_claim_slot(tp_producer_t *producer, uint16_t pool_id, tp_slot_claim_t *claim)
{
    if ((producer == NULL) || (claim == NULL))
    {
        return TP_ERR_ARG;
    }
    if ((producer->revoked) || (producer->client->driver.shutdown))
    {
        producer->revoked = true;
        return TP_ERR_PROTOCOL;
    }
    if ((producer->client->driver.revoked_lease_id == producer->lease_id) &&
        (producer->client->driver.revoked_role == shm_tensorpool_driver_role_PRODUCER))
    {
        producer->revoked = true;
        return TP_ERR_PROTOCOL;
    }
    if (producer->client->driver.revoked_lease_id == producer->lease_id &&
        producer->client->driver.revoked_role == shm_tensorpool_driver_role_PRODUCER)
    {
        producer->revoked = true;
        return TP_ERR_PROTOCOL;
    }
    tp_pool_mapping_t *pool = tp_find_pool(producer, pool_id);
    if (pool == NULL)
    {
        return TP_ERR_ARG;
    }
    uint32_t header_index = (uint32_t)(producer->seq & (producer->header_nslots - 1));
    uint32_t payload_slot = header_index;
    if (payload_slot >= pool->nslots)
    {
        return TP_ERR_PROTOCOL;
    }

    uint8_t *header_base = producer->header.addr;
    uint64_t header_offset = TP_SUPERBLOCK_SIZE + ((uint64_t)header_index * producer->header_slot_bytes);
    uint64_t *commit_ptr = (uint64_t *)(header_base + header_offset);
    __atomic_store_n(commit_ptr, (producer->seq << 1) | 1, __ATOMIC_RELEASE);

    uint8_t *payload = pool->mapping.addr + TP_SUPERBLOCK_SIZE + ((uint64_t)payload_slot * pool->stride_bytes);

    claim->seq = producer->seq;
    claim->ptr = payload;
    claim->stride_bytes = pool->stride_bytes;
    claim->header_index = header_index;
    claim->payload_slot = payload_slot;
    claim->pool_id = pool_id;
    producer->seq += 1;
    return TP_OK;
}

tp_err_t tp_producer_try_claim_slot_by_size(tp_producer_t *producer, uint32_t values_len, tp_slot_claim_t *claim)
{
    if ((producer == NULL) || (claim == NULL))
    {
        return TP_ERR_ARG;
    }
    tp_pool_mapping_t *pool = tp_select_pool(producer, values_len);
    if (pool == NULL)
    {
        return TP_ERR_ARG;
    }
    return tp_producer_try_claim_slot(producer, pool->pool_id, claim);
}

static tp_err_t tp_write_slot_header(
    tp_producer_t *producer,
    tp_slot_claim_t *claim,
    uint32_t values_len,
    const tp_tensor_header_t *tensor,
    uint32_t meta_version)
{
    uint64_t header_offset = TP_SUPERBLOCK_SIZE + ((uint64_t)claim->header_index * producer->header_slot_bytes);
    uint8_t *header_base = producer->header.addr;

    struct shm_tensorpool_control_slotHeader slot;
    shm_tensorpool_control_slotHeader_wrap_for_encode(
        &slot,
        (char *)header_base + header_offset,
        0,
        producer->header.length - header_offset);

    shm_tensorpool_control_slotHeader_set_valuesLenBytes(&slot, values_len);
    shm_tensorpool_control_slotHeader_set_payloadSlot(&slot, claim->payload_slot);
    shm_tensorpool_control_slotHeader_set_poolId(&slot, claim->pool_id);
    shm_tensorpool_control_slotHeader_set_payloadOffset(&slot, 0);
    shm_tensorpool_control_slotHeader_set_timestampNs(&slot, tp_now_ns());
    shm_tensorpool_control_slotHeader_set_metaVersion(&slot, meta_version);

    uint64_t tensor_len =
        shm_tensorpool_control_messageHeader_encoded_length() +
        shm_tensorpool_control_tensorHeader_sbe_block_length();
    uint8_t header_buf[256];
    if (tensor_len > sizeof(header_buf))
    {
        return TP_ERR_PROTOCOL;
    }

    struct shm_tensorpool_control_messageHeader hdr;
    struct shm_tensorpool_control_tensorHeader tensor_msg;
    shm_tensorpool_control_messageHeader_wrap(
        &hdr,
        (char *)header_buf,
        0,
        shm_tensorpool_control_messageHeader_sbe_schema_version(),
        sizeof(header_buf));
    shm_tensorpool_control_messageHeader_set_blockLength(&hdr, shm_tensorpool_control_tensorHeader_sbe_block_length());
    shm_tensorpool_control_messageHeader_set_templateId(&hdr, shm_tensorpool_control_tensorHeader_sbe_template_id());
    shm_tensorpool_control_messageHeader_set_schemaId(&hdr, shm_tensorpool_control_tensorHeader_sbe_schema_id());
    shm_tensorpool_control_messageHeader_set_version(&hdr, shm_tensorpool_control_tensorHeader_sbe_schema_version());

    shm_tensorpool_control_tensorHeader_wrap_for_encode(
        &tensor_msg,
        (char *)header_buf + shm_tensorpool_control_messageHeader_encoded_length(),
        0,
        sizeof(header_buf) - shm_tensorpool_control_messageHeader_encoded_length());

    shm_tensorpool_control_tensorHeader_set_dtype(&tensor_msg, tensor->dtype);
    shm_tensorpool_control_tensorHeader_set_majorOrder(&tensor_msg, tensor->major_order);
    shm_tensorpool_control_tensorHeader_set_ndims(&tensor_msg, tensor->ndims);
    shm_tensorpool_control_tensorHeader_set_padAlign(&tensor_msg, tensor->pad_align);
    shm_tensorpool_control_tensorHeader_set_progressUnit(&tensor_msg, tensor->progress_unit);
    shm_tensorpool_control_tensorHeader_set_progressStrideBytes(&tensor_msg, tensor->progress_stride_bytes);
    for (uint32_t i = 0; i < TP_MAX_DIMS; i++)
    {
        shm_tensorpool_control_tensorHeader_set_dims_unsafe(&tensor_msg, i, tensor->dims[i]);
        shm_tensorpool_control_tensorHeader_set_strides_unsafe(&tensor_msg, i, tensor->strides[i]);
    }
    if (shm_tensorpool_control_slotHeader_put_headerBytes(
            &slot,
            (char *)header_buf,
            (uint32_t)tensor_len) == NULL)
    {
        return TP_ERR_PROTOCOL;
    }

    return TP_OK;
}

static tp_err_t tp_publish_descriptor(tp_producer_t *producer, tp_slot_claim_t *claim, uint32_t meta_version)
{
    aeron_buffer_claim_t claim_buf;
    uint64_t msg_len = shm_tensorpool_control_messageHeader_encoded_length() +
        shm_tensorpool_control_frameDescriptor_sbe_block_length();
    int64_t position = aeron_publication_try_claim(producer->pub_descriptor, msg_len, &claim_buf);
    if (position < 0)
    {
        const char *debug_env = getenv("TP_DEBUG_PUB");
        if (debug_env != NULL && debug_env[0] != '\0')
        {
            const char *reason = "UNKNOWN";
            if (position == AERON_PUBLICATION_NOT_CONNECTED)
            {
                reason = "NOT_CONNECTED";
            }
            else if (position == AERON_PUBLICATION_BACK_PRESSURED)
            {
                reason = "BACK_PRESSURED";
            }
            else if (position == AERON_PUBLICATION_ADMIN_ACTION)
            {
                reason = "ADMIN_ACTION";
            }
            fprintf(stderr,
                "tp_publish_descriptor: try_claim failed (%s, position=%lld, errcode=%d, errmsg=%s)\n",
                reason,
                (long long)position,
                aeron_errcode(),
                aeron_errmsg());
        }
        return TP_ERR_AERON;
    }

    struct shm_tensorpool_control_messageHeader hdr;
    struct shm_tensorpool_control_frameDescriptor desc;
    shm_tensorpool_control_frameDescriptor_wrap_and_apply_header(
        &desc,
        (char *)claim_buf.data,
        0,
        msg_len,
        &hdr);
    shm_tensorpool_control_frameDescriptor_set_streamId(&desc, producer->stream_id);
    shm_tensorpool_control_frameDescriptor_set_epoch(&desc, producer->epoch);
    shm_tensorpool_control_frameDescriptor_set_seq(&desc, claim->seq);
    shm_tensorpool_control_frameDescriptor_set_headerIndex(&desc, claim->header_index);
    shm_tensorpool_control_frameDescriptor_set_timestampNs(&desc, tp_now_ns());
    shm_tensorpool_control_frameDescriptor_set_metaVersion(&desc, meta_version);

    aeron_buffer_claim_commit(&claim_buf);
    return TP_OK;
}

tp_err_t tp_producer_commit_slot(
    tp_producer_t *producer,
    tp_slot_claim_t *claim,
    uint32_t values_len,
    const tp_tensor_header_t *tensor,
    uint32_t meta_version)
{
    if ((producer == NULL) || (claim == NULL) || (tensor == NULL))
    {
        return TP_ERR_ARG;
    }
    if ((producer->revoked) || (producer->client->driver.shutdown))
    {
        return TP_ERR_PROTOCOL;
    }
    if (producer->client->driver.revoked_lease_id == producer->lease_id &&
        producer->client->driver.revoked_role == shm_tensorpool_driver_role_PRODUCER)
    {
        producer->revoked = true;
        return TP_ERR_PROTOCOL;
    }
    if (values_len > claim->stride_bytes)
    {
        return TP_ERR_ARG;
    }
    tp_err_t err = tp_write_slot_header(producer, claim, values_len, tensor, meta_version);
    if (err != TP_OK)
    {
        return err;
    }
    uint64_t header_offset = TP_SUPERBLOCK_SIZE + ((uint64_t)claim->header_index * producer->header_slot_bytes);
    uint64_t *commit_ptr = (uint64_t *)(producer->header.addr + header_offset);
    __atomic_store_n(commit_ptr, claim->seq << 1, __ATOMIC_RELEASE);
    return tp_publish_descriptor(producer, claim, meta_version);
}

tp_err_t tp_producer_offer_frame(
    tp_producer_t *producer,
    const uint8_t *payload,
    uint32_t values_len,
    const tp_tensor_header_t *tensor,
    uint32_t meta_version)
{
    if ((producer == NULL) || (payload == NULL) || (tensor == NULL))
    {
        return TP_ERR_ARG;
    }
    if ((producer->revoked) || (producer->client->driver.shutdown))
    {
        return TP_ERR_PROTOCOL;
    }
    if (producer->client->driver.revoked_lease_id == producer->lease_id &&
        producer->client->driver.revoked_role == shm_tensorpool_driver_role_PRODUCER)
    {
        producer->revoked = true;
        return TP_ERR_PROTOCOL;
    }
    tp_pool_mapping_t *pool = tp_select_pool(producer, values_len);
    if (pool == NULL)
    {
        return TP_ERR_ARG;
    }
    tp_slot_claim_t claim;
    tp_err_t err = tp_producer_try_claim_slot(producer, pool->pool_id, &claim);
    if (err != TP_OK)
    {
        return err;
    }
    memcpy(claim.ptr, payload, values_len);
    return tp_producer_commit_slot(producer, &claim, values_len, tensor, meta_version);
}

tp_err_t tp_producer_send_qos(tp_producer_t *producer, uint64_t current_seq, uint64_t watermark)
{
    if ((producer == NULL) || (producer->pub_qos == NULL))
    {
        return TP_ERR_ARG;
    }
    aeron_buffer_claim_t claim_buf;
    uint64_t msg_len = shm_tensorpool_control_messageHeader_encoded_length() +
        shm_tensorpool_control_qosProducer_sbe_block_length();
    int64_t position = aeron_publication_try_claim(producer->pub_qos, msg_len, &claim_buf);
    if (position < 0)
    {
        return TP_ERR_AERON;
    }

    struct shm_tensorpool_control_messageHeader hdr;
    struct shm_tensorpool_control_qosProducer msg;
    shm_tensorpool_control_qosProducer_wrap_and_apply_header(
        &msg,
        (char *)claim_buf.data,
        0,
        msg_len,
        &hdr);
    shm_tensorpool_control_qosProducer_set_streamId(&msg, producer->stream_id);
    shm_tensorpool_control_qosProducer_set_producerId(&msg, producer->client->context->client_id);
    shm_tensorpool_control_qosProducer_set_epoch(&msg, producer->epoch);
    shm_tensorpool_control_qosProducer_set_currentSeq(&msg, current_seq);
    shm_tensorpool_control_qosProducer_set_watermark(&msg, watermark);

    aeron_buffer_claim_commit(&claim_buf);
    return TP_OK;
}

tp_err_t tp_producer_poll(tp_producer_t *producer)
{
    if (producer == NULL)
    {
        return TP_ERR_ARG;
    }
    if ((producer->revoked) || (producer->client->driver.shutdown))
    {
        return TP_ERR_PROTOCOL;
    }
    uint64_t now_ns = tp_now_ns();
    uint64_t keepalive_interval = producer->client->context->lease_keepalive_interval_ns;
    if (keepalive_interval > 0 && now_ns - producer->last_keepalive_ns >= keepalive_interval)
    {
        tp_err_t err = tp_lease_keepalive(
            producer->client,
            producer->lease_id,
            producer->stream_id,
            producer->client->context->client_id,
            shm_tensorpool_driver_role_PRODUCER);
        if (err != TP_OK)
        {
            producer->revoked = true;
            return TP_ERR_PROTOCOL;
        }
        producer->last_keepalive_ns = now_ns;
    }
    if (producer->pub_qos == NULL)
    {
        if (producer->pub_metadata == NULL || !producer->metadata_dirty)
        {
            return TP_OK;
        }
    }
    if (producer->pub_metadata && producer->metadata_dirty)
    {
        tp_err_t err = tp_producer_send_metadata_announce(
            producer,
            producer->metadata_version,
            producer->metadata_name,
            producer->metadata_summary);
        if (err != TP_OK)
        {
            return err;
        }
        err = tp_producer_send_metadata_meta(
            producer,
            producer->metadata_version,
            now_ns,
            producer->metadata_attrs,
            producer->metadata_attr_count);
        if (err != TP_OK)
        {
            return err;
        }
        producer->metadata_dirty = false;
    }
    if (now_ns - producer->last_qos_ns >= producer->client->context->qos_interval_ns)
    {
        tp_err_t err = tp_producer_send_qos(producer, producer->seq, 0);
        if (err == TP_OK)
        {
            producer->last_qos_ns = now_ns;
        }
        return err;
    }
    return TP_OK;
}

static uint32_t tp_metadata_text_len(const char *text, uint32_t max_len)
{
    if (text == NULL)
    {
        return 0;
    }
    size_t len = strnlen(text, max_len);
    return (uint32_t)len;
}

static uint64_t tp_metadata_announce_length(const char *name, const char *summary)
{
    uint64_t length = shm_tensorpool_control_messageHeader_encoded_length() +
        shm_tensorpool_control_dataSourceAnnounce_sbe_block_length();
    length += shm_tensorpool_control_dataSourceAnnounce_name_header_length();
    length += tp_metadata_text_len(name, TP_METADATA_TEXT_MAX);
    length += shm_tensorpool_control_dataSourceAnnounce_summary_header_length();
    length += tp_metadata_text_len(summary, TP_METADATA_TEXT_MAX);
    return length;
}

static uint64_t tp_metadata_meta_length(const tp_metadata_attribute_t *attrs, uint32_t attr_count)
{
    uint64_t length = shm_tensorpool_control_messageHeader_encoded_length() +
        shm_tensorpool_control_dataSourceMeta_sbe_block_length();
    length += shm_tensorpool_control_dataSourceMeta_attributes_sbe_header_size();
    length += (uint64_t)attr_count * shm_tensorpool_control_dataSourceMeta_attributes_sbe_block_length();
    for (uint32_t i = 0; i < attr_count; i++)
    {
        length += shm_tensorpool_control_dataSourceMeta_attributes_key_header_length();
        length += tp_metadata_text_len(attrs[i].key, TP_METADATA_TEXT_MAX);
        length += shm_tensorpool_control_dataSourceMeta_attributes_format_header_length();
        length += tp_metadata_text_len(attrs[i].mime_type, TP_METADATA_TEXT_MAX);
        length += shm_tensorpool_control_dataSourceMeta_attributes_value_header_length();
        length += attrs[i].value_len;
    }
    return length;
}

tp_err_t tp_producer_send_metadata_announce(
    tp_producer_t *producer,
    uint32_t meta_version,
    const char *name,
    const char *summary)
{
    if ((producer == NULL) || (producer->pub_metadata == NULL))
    {
        return TP_ERR_ARG;
    }
    aeron_buffer_claim_t claim_buf;
    uint64_t msg_len = tp_metadata_announce_length(name, summary);
    int64_t position = aeron_publication_try_claim(producer->pub_metadata, msg_len, &claim_buf);
    if (position < 0)
    {
        return TP_ERR_AERON;
    }

    struct shm_tensorpool_control_messageHeader hdr;
    struct shm_tensorpool_control_dataSourceAnnounce msg;
    shm_tensorpool_control_dataSourceAnnounce_wrap_and_apply_header(
        &msg,
        (char *)claim_buf.data,
        0,
        msg_len,
        &hdr);
    shm_tensorpool_control_dataSourceAnnounce_set_streamId(&msg, producer->stream_id);
    shm_tensorpool_control_dataSourceAnnounce_set_producerId(&msg, producer->client->context->client_id);
    shm_tensorpool_control_dataSourceAnnounce_set_epoch(&msg, producer->epoch);
    shm_tensorpool_control_dataSourceAnnounce_set_metaVersion(&msg, meta_version);
    shm_tensorpool_control_dataSourceAnnounce_put_name(
        &msg,
        name == NULL ? "" : name,
        tp_metadata_text_len(name, TP_METADATA_TEXT_MAX));
    shm_tensorpool_control_dataSourceAnnounce_put_summary(
        &msg,
        summary == NULL ? "" : summary,
        tp_metadata_text_len(summary, TP_METADATA_TEXT_MAX));

    aeron_buffer_claim_commit(&claim_buf);
    return TP_OK;
}

tp_err_t tp_producer_send_metadata_meta(
    tp_producer_t *producer,
    uint32_t meta_version,
    uint64_t timestamp_ns,
    const tp_metadata_attribute_t *attrs,
    uint32_t attr_count)
{
    if ((producer == NULL) || (producer->pub_metadata == NULL) || (attrs == NULL && attr_count > 0))
    {
        return TP_ERR_ARG;
    }
    if (attr_count > TP_MAX_METADATA_ATTRS)
    {
        return TP_ERR_ARG;
    }
    aeron_buffer_claim_t claim_buf;
    uint64_t msg_len = tp_metadata_meta_length(attrs, attr_count);
    int64_t position = aeron_publication_try_claim(producer->pub_metadata, msg_len, &claim_buf);
    if (position < 0)
    {
        return TP_ERR_AERON;
    }

    struct shm_tensorpool_control_messageHeader hdr;
    struct shm_tensorpool_control_dataSourceMeta msg;
    shm_tensorpool_control_dataSourceMeta_wrap_and_apply_header(
        &msg,
        (char *)claim_buf.data,
        0,
        msg_len,
        &hdr);
    shm_tensorpool_control_dataSourceMeta_set_streamId(&msg, producer->stream_id);
    shm_tensorpool_control_dataSourceMeta_set_metaVersion(&msg, meta_version);
    shm_tensorpool_control_dataSourceMeta_set_timestampNs(&msg, timestamp_ns);

    struct shm_tensorpool_control_dataSourceMeta_attributes attrs_group;
    shm_tensorpool_control_dataSourceMeta_attributes_set_count(&msg, &attrs_group, attr_count);
    for (uint32_t i = 0; i < attr_count; i++)
    {
        shm_tensorpool_control_dataSourceMeta_attributes_next(&attrs_group);
        uint32_t key_len = tp_metadata_text_len(attrs[i].key, TP_METADATA_TEXT_MAX);
        uint32_t format_len = tp_metadata_text_len(attrs[i].mime_type, TP_METADATA_TEXT_MAX);
        shm_tensorpool_control_dataSourceMeta_attributes_put_key(
            &attrs_group,
            attrs[i].key,
            key_len);
        shm_tensorpool_control_dataSourceMeta_attributes_put_format(
            &attrs_group,
            attrs[i].mime_type,
            format_len);
        shm_tensorpool_control_dataSourceMeta_attributes_put_value(
            &attrs_group,
            (const char *)attrs[i].value,
            attrs[i].value_len);
    }

    aeron_buffer_claim_commit(&claim_buf);
    return TP_OK;
}

static tp_err_t tp_metadata_copy_text(char *dst, size_t dst_len, const char *src)
{
    if ((dst == NULL) || (dst_len == 0))
    {
        return TP_ERR_ARG;
    }
    snprintf(dst, dst_len, "%s", src == NULL ? "" : src);
    return TP_OK;
}

static tp_err_t tp_metadata_copy_attribute(tp_metadata_attribute_t *dst, const char *key, const char *mime_type, const uint8_t *value, uint32_t value_len)
{
    if ((dst == NULL) || (key == NULL) || (mime_type == NULL))
    {
        return TP_ERR_ARG;
    }
    if (value_len > TP_METADATA_VALUE_MAX)
    {
        return TP_ERR_ARG;
    }
    tp_err_t err = tp_metadata_copy_text(dst->key, sizeof(dst->key), key);
    if (err != TP_OK)
    {
        return err;
    }
    err = tp_metadata_copy_text(dst->mime_type, sizeof(dst->mime_type), mime_type);
    if (err != TP_OK)
    {
        return err;
    }
    dst->value_len = value_len;
    if (value_len > 0 && value != NULL)
    {
        memcpy(dst->value, value, value_len);
    }
    return TP_OK;
}

static int tp_metadata_find_attr(const tp_producer_t *producer, const char *key)
{
    if ((producer == NULL) || (key == NULL))
    {
        return -1;
    }
    for (uint32_t i = 0; i < producer->metadata_attr_count; i++)
    {
        if (strncmp(producer->metadata_attrs[i].key, key, TP_METADATA_TEXT_MAX) == 0)
        {
            return (int)i;
        }
    }
    return -1;
}

static uint32_t tp_producer_next_meta_version(tp_producer_t *producer)
{
    producer->metadata_version += 1;
    return producer->metadata_version;
}

tp_err_t tp_producer_metadata_version(const tp_producer_t *producer, uint32_t *meta_version)
{
    if ((producer == NULL) || (meta_version == NULL))
    {
        return TP_ERR_ARG;
    }
    *meta_version = producer->metadata_version;
    return TP_OK;
}

tp_err_t tp_producer_set_metadata(
    tp_producer_t *producer,
    const char *name,
    const char *summary,
    const tp_metadata_attribute_t *attrs,
    uint32_t attr_count)
{
    if (producer == NULL)
    {
        return TP_ERR_ARG;
    }
    if (attr_count > TP_MAX_METADATA_ATTRS)
    {
        return TP_ERR_ARG;
    }
    tp_err_t err = tp_metadata_copy_text(producer->metadata_name, sizeof(producer->metadata_name), name);
    if (err != TP_OK)
    {
        return err;
    }
    err = tp_metadata_copy_text(producer->metadata_summary, sizeof(producer->metadata_summary), summary);
    if (err != TP_OK)
    {
        return err;
    }
    producer->metadata_attr_count = 0;
    if (attrs != NULL)
    {
        for (uint32_t i = 0; i < attr_count; i++)
        {
            err = tp_metadata_copy_attribute(
                &producer->metadata_attrs[i],
                attrs[i].key,
                attrs[i].mime_type,
                attrs[i].value,
                attrs[i].value_len);
            if (err != TP_OK)
            {
                return err;
            }
            producer->metadata_attr_count++;
        }
    }
    tp_producer_next_meta_version(producer);
    producer->metadata_dirty = true;
    return TP_OK;
}

tp_err_t tp_producer_announce_data_source(tp_producer_t *producer, const char *name, const char *summary)
{
    if (producer == NULL)
    {
        return TP_ERR_ARG;
    }
    tp_err_t err = tp_metadata_copy_text(producer->metadata_name, sizeof(producer->metadata_name), name);
    if (err != TP_OK)
    {
        return err;
    }
    err = tp_metadata_copy_text(producer->metadata_summary, sizeof(producer->metadata_summary), summary);
    if (err != TP_OK)
    {
        return err;
    }
    tp_producer_next_meta_version(producer);
    producer->metadata_dirty = true;
    return TP_OK;
}

tp_err_t tp_producer_set_metadata_attributes(
    tp_producer_t *producer,
    const tp_metadata_attribute_t *attrs,
    uint32_t attr_count)
{
    if (producer == NULL)
    {
        return TP_ERR_ARG;
    }
    if (attrs == NULL && attr_count > 0)
    {
        return TP_ERR_ARG;
    }
    if (attr_count > TP_MAX_METADATA_ATTRS)
    {
        return TP_ERR_ARG;
    }
    producer->metadata_attr_count = 0;
    if (attrs != NULL)
    {
        for (uint32_t i = 0; i < attr_count; i++)
        {
            tp_err_t err = tp_metadata_copy_attribute(
                &producer->metadata_attrs[i],
                attrs[i].key,
                attrs[i].mime_type,
                attrs[i].value,
                attrs[i].value_len);
            if (err != TP_OK)
            {
                return err;
            }
            producer->metadata_attr_count++;
        }
    }
    tp_producer_next_meta_version(producer);
    producer->metadata_dirty = true;
    return TP_OK;
}

tp_err_t tp_producer_set_metadata_attribute(
    tp_producer_t *producer,
    const char *key,
    const char *mime_type,
    const uint8_t *value,
    uint32_t value_len)
{
    if (producer == NULL)
    {
        return TP_ERR_ARG;
    }
    tp_producer_next_meta_version(producer);
    int idx = tp_metadata_find_attr(producer, key);
    if (idx < 0)
    {
        if (producer->metadata_attr_count >= TP_MAX_METADATA_ATTRS)
        {
            return TP_ERR_ARG;
        }
        idx = (int)producer->metadata_attr_count++;
    }
    tp_err_t err = tp_metadata_copy_attribute(&producer->metadata_attrs[idx], key, mime_type, value, value_len);
    if (err != TP_OK)
    {
        return err;
    }
    producer->metadata_dirty = true;
    return TP_OK;
}

tp_err_t tp_producer_delete_metadata_attribute(tp_producer_t *producer, const char *key)
{
    if ((producer == NULL) || (key == NULL))
    {
        return TP_ERR_ARG;
    }
    int idx = tp_metadata_find_attr(producer, key);
    if (idx < 0)
    {
        return TP_ERR_NOT_FOUND;
    }
    for (uint32_t i = (uint32_t)idx + 1; i < producer->metadata_attr_count; i++)
    {
        producer->metadata_attrs[i - 1] = producer->metadata_attrs[i];
    }
    producer->metadata_attr_count--;
    tp_producer_next_meta_version(producer);
    producer->metadata_dirty = true;
    return TP_OK;
}

void tp_producer_close(tp_producer_t *producer)
{
    if (producer == NULL)
    {
        return;
    }
    if (producer->pub_descriptor)
    {
        aeron_publication_close(producer->pub_descriptor, NULL, NULL);
    }
    if (producer->pub_metadata)
    {
        aeron_publication_close(producer->pub_metadata, NULL, NULL);
    }
    if (producer->pub_qos)
    {
        aeron_publication_close(producer->pub_qos, NULL, NULL);
    }
    tp_shm_unmap(&producer->header);
    for (uint32_t i = 0; i < producer->pool_count; i++)
    {
        tp_shm_unmap(&producer->pools[i].mapping);
    }
    free(producer);
}

bool tp_producer_is_connected(const tp_producer_t *producer)
{
    if ((producer == NULL) || (producer->pub_descriptor == NULL))
    {
        return false;
    }
    return aeron_publication_is_connected(producer->pub_descriptor);
}

tp_err_t tp_producer_get_lease_id(const tp_producer_t *producer, uint64_t *lease_id)
{
    if ((producer == NULL) || (lease_id == NULL))
    {
        return TP_ERR_ARG;
    }
    *lease_id = producer->lease_id;
    return TP_OK;
}

tp_err_t tp_producer_get_stream_id(const tp_producer_t *producer, uint32_t *stream_id)
{
    if ((producer == NULL) || (stream_id == NULL))
    {
        return TP_ERR_ARG;
    }
    *stream_id = producer->stream_id;
    return TP_OK;
}

tp_err_t tp_producer_get_producer_id(const tp_producer_t *producer, uint32_t *producer_id)
{
    if ((producer == NULL) || (producer_id == NULL))
    {
        return TP_ERR_ARG;
    }
    *producer_id = producer->client->context->client_id;
    return TP_OK;
}
