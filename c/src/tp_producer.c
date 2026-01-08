#include "tp_internal.h"

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

    *out = producer;
    return TP_OK;
}

tp_err_t tp_attach_producer(tp_client_t *client, uint32_t stream_id, tp_producer_t **producer)
{
    if (client == NULL || producer == NULL)
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
        return err;
    }
    if (resp.code != shm_tensorpool_driver_responseCode_OK)
    {
        return TP_ERR_PROTOCOL;
    }
    return tp_init_producer_from_attach(client, &resp, producer);
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
    if (producer == NULL || claim == NULL)
    {
        return TP_ERR_ARG;
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
    if (producer == NULL || claim == NULL)
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
    if (producer == NULL || claim == NULL || tensor == NULL)
    {
        return TP_ERR_ARG;
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
    if (producer == NULL || payload == NULL || tensor == NULL)
    {
        return TP_ERR_ARG;
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
    tp_shm_unmap(&producer->header);
    for (uint32_t i = 0; i < producer->pool_count; i++)
    {
        tp_shm_unmap(&producer->pools[i].mapping);
    }
    free(producer);
}

bool tp_producer_is_connected(tp_producer_t *producer)
{
    if (producer == NULL || producer->pub_descriptor == NULL)
    {
        return false;
    }
    return aeron_publication_is_connected(producer->pub_descriptor);
}
