#include "tp_internal.h"
#include <stdio.h>

static void tp_descriptor_handler(void *clientd, const uint8_t *buffer, size_t length, aeron_header_t *header)
{
    (void)header;
    tp_consumer_t *consumer = (tp_consumer_t *)clientd;
    if (length < shm_tensorpool_control_messageHeader_encoded_length())
    {
        return;
    }

    struct shm_tensorpool_control_messageHeader hdr;
    if (!shm_tensorpool_control_messageHeader_wrap(
            &hdr, (char *)buffer, 0, shm_tensorpool_control_messageHeader_sbe_schema_version(), length))
    {
        return;
    }
    if (shm_tensorpool_control_messageHeader_templateId(&hdr) != shm_tensorpool_control_frameDescriptor_sbe_template_id())
    {
        return;
    }

    struct shm_tensorpool_control_frameDescriptor desc;
    uint64_t acting_block_length = shm_tensorpool_control_messageHeader_blockLength(&hdr);
    uint64_t acting_version = shm_tensorpool_control_messageHeader_version(&hdr);
    shm_tensorpool_control_frameDescriptor_wrap_for_decode(
        &desc,
        (char *)buffer + shm_tensorpool_control_messageHeader_encoded_length(),
        0,
        acting_block_length,
        acting_version,
        length - shm_tensorpool_control_messageHeader_encoded_length());

    consumer->last_seq = shm_tensorpool_control_frameDescriptor_seq(&desc);
    consumer->last_header_index = shm_tensorpool_control_frameDescriptor_headerIndex(&desc);
    consumer->last_meta_version = shm_tensorpool_control_frameDescriptor_metaVersion(&desc);
    consumer->has_descriptor = true;
}

static tp_err_t tp_init_consumer_from_attach(tp_client_t *client, const tp_attach_response_t *resp, tp_consumer_t **out)
{
    tp_consumer_t *consumer = (tp_consumer_t *)calloc(1, sizeof(tp_consumer_t));
    if (consumer == NULL)
    {
        return TP_ERR_NOMEM;
    }
    consumer->client = client;
    consumer->lease_id = resp->lease_id;
    consumer->stream_id = resp->stream_id;
    consumer->epoch = resp->epoch;
    consumer->layout_version = resp->layout_version;
    consumer->header_nslots = resp->header_nslots;
    consumer->header_slot_bytes = resp->header_slot_bytes;
    consumer->pool_count = resp->pool_count;

    size_t header_size = TP_SUPERBLOCK_SIZE + (size_t)resp->header_nslots * resp->header_slot_bytes;
    if (tp_shm_map(resp->header_uri, header_size, false, &consumer->header) != TP_OK)
    {
        tp_consumer_close(consumer);
        return TP_ERR_SHM;
    }
    if (tp_shm_validate_superblock(
            &consumer->header,
            resp->layout_version,
            resp->epoch,
            resp->stream_id,
            resp->header_nslots,
            resp->header_slot_bytes,
            0,
            0,
            shm_tensorpool_control_regionType_HEADER_RING) != TP_OK)
    {
        tp_consumer_close(consumer);
        return TP_ERR_PROTOCOL;
    }

    for (uint32_t i = 0; i < resp->pool_count; i++)
    {
        consumer->pools[i].pool_id = resp->pools[i].pool_id;
        consumer->pools[i].nslots = resp->pools[i].nslots;
        consumer->pools[i].stride_bytes = resp->pools[i].stride_bytes;
        size_t pool_size = TP_SUPERBLOCK_SIZE + (size_t)resp->pools[i].nslots * resp->pools[i].stride_bytes;
        if (tp_shm_map(resp->pools[i].uri, pool_size, false, &consumer->pools[i].mapping) != TP_OK)
        {
            tp_consumer_close(consumer);
            return TP_ERR_SHM;
        }
        if (tp_shm_validate_superblock(
                &consumer->pools[i].mapping,
                resp->layout_version,
                resp->epoch,
                resp->stream_id,
                resp->pools[i].nslots,
                resp->pools[i].stride_bytes,
                resp->pools[i].stride_bytes,
                resp->pools[i].pool_id,
                shm_tensorpool_control_regionType_PAYLOAD_POOL) != TP_OK)
        {
            tp_consumer_close(consumer);
            return TP_ERR_PROTOCOL;
        }
    }

    if (tp_add_subscription(client->aeron, client->context->descriptor_channel, client->context->descriptor_stream_id, &consumer->sub_descriptor) < 0)
    {
        tp_consumer_close(consumer);
        return TP_ERR_AERON;
    }
    if (aeron_fragment_assembler_create(&consumer->descriptor_assembler, tp_descriptor_handler, consumer) < 0)
    {
        tp_consumer_close(consumer);
        return TP_ERR_AERON;
    }

    *out = consumer;
    return TP_OK;
}

tp_err_t tp_attach_consumer(tp_client_t *client, uint32_t stream_id, tp_consumer_t **consumer)
{
    if (client == NULL || consumer == NULL)
    {
        return TP_ERR_ARG;
    }
    tp_err_t err = tp_send_attach_request(client, stream_id, shm_tensorpool_driver_role_CONSUMER, shm_tensorpool_driver_publishMode_REQUIRE_EXISTING);
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
            fprintf(stderr, "tp_attach_consumer: wait_attach failed (err=%d)\n", err);
        }
        return err;
    }
    if (resp.code != shm_tensorpool_driver_responseCode_OK)
    {
        const char *debug_env = getenv("TP_DEBUG_ATTACH");
        if (debug_env != NULL && debug_env[0] != '\0')
        {
            fprintf(stderr,
                "tp_attach_consumer: attach rejected (code=%d, error=%s)\n",
                resp.code,
                resp.error_message);
        }
        return TP_ERR_PROTOCOL;
    }
    return tp_init_consumer_from_attach(client, &resp, consumer);
}

tp_err_t tp_consumer_poll(tp_consumer_t *consumer, int fragment_limit)
{
    if (consumer == NULL || consumer->sub_descriptor == NULL)
    {
        return TP_ERR_ARG;
    }
    aeron_subscription_poll(
        consumer->sub_descriptor,
        aeron_fragment_assembler_handler,
        consumer->descriptor_assembler,
        (size_t)fragment_limit);
    return TP_OK;
}

static tp_pool_mapping_t *tp_consumer_find_pool(tp_consumer_t *consumer, uint16_t pool_id)
{
    for (uint32_t i = 0; i < consumer->pool_count; i++)
    {
        if (consumer->pools[i].pool_id == pool_id)
        {
            return &consumer->pools[i];
        }
    }
    return NULL;
}

tp_err_t tp_consumer_try_read_frame(tp_consumer_t *consumer, tp_frame_view_t *view)
{
    if (consumer == NULL || view == NULL)
    {
        return TP_ERR_ARG;
    }
    if (!consumer->has_descriptor)
    {
        return TP_ERR_TIMEOUT;
    }

    uint32_t header_index = consumer->last_header_index;
    uint64_t header_offset = TP_SUPERBLOCK_SIZE + ((uint64_t)header_index * consumer->header_slot_bytes);
    uint64_t *commit_ptr = (uint64_t *)(consumer->header.addr + header_offset);
    uint64_t begin = __atomic_load_n(commit_ptr, __ATOMIC_ACQUIRE);
    if ((begin & 1ULL) != 0)
    {
        return TP_ERR_TIMEOUT;
    }

    struct shm_tensorpool_control_slotHeader slot;
    shm_tensorpool_control_slotHeader_wrap_for_decode(
        &slot,
        (char *)consumer->header.addr + header_offset,
        0,
        shm_tensorpool_control_slotHeader_sbe_block_length(),
        shm_tensorpool_control_slotHeader_sbe_schema_version(),
        consumer->header.length - header_offset);

    struct shm_tensorpool_control_slotHeader_string_view header_view =
        shm_tensorpool_control_slotHeader_get_headerBytes_as_string_view(&slot);
    if (header_view.data == NULL)
    {
        return TP_ERR_PROTOCOL;
    }
    uint32_t header_len = header_view.length;
    if (header_len != (shm_tensorpool_control_messageHeader_encoded_length() +
        shm_tensorpool_control_tensorHeader_sbe_block_length()))
    {
        if (getenv("TP_DEBUG_FRAME") != NULL)
        {
            fprintf(stderr, "headerBytes length mismatch: %u\n", header_len);
        }
        return TP_ERR_PROTOCOL;
    }

    struct shm_tensorpool_control_messageHeader hdr;
    if (!shm_tensorpool_control_messageHeader_wrap(
            &hdr,
            (char *)header_view.data,
            0,
            shm_tensorpool_control_messageHeader_sbe_schema_version(),
            header_len))
    {
        if (getenv("TP_DEBUG_FRAME") != NULL)
        {
            fprintf(stderr, "messageHeader wrap failed\n");
        }
        return TP_ERR_PROTOCOL;
    }
    if (shm_tensorpool_control_messageHeader_templateId(&hdr) != shm_tensorpool_control_tensorHeader_sbe_template_id())
    {
        if (getenv("TP_DEBUG_FRAME") != NULL)
        {
            fprintf(stderr, "tensorHeader template mismatch: %u\n",
                shm_tensorpool_control_messageHeader_templateId(&hdr));
        }
        return TP_ERR_PROTOCOL;
    }
    if (shm_tensorpool_control_messageHeader_blockLength(&hdr) != shm_tensorpool_control_tensorHeader_sbe_block_length())
    {
        if (getenv("TP_DEBUG_FRAME") != NULL)
        {
            fprintf(stderr, "tensorHeader block length mismatch: %u\n",
                shm_tensorpool_control_messageHeader_blockLength(&hdr));
        }
        return TP_ERR_PROTOCOL;
    }

    struct shm_tensorpool_control_tensorHeader tensor;
    shm_tensorpool_control_tensorHeader_wrap_for_decode(
        &tensor,
        (char *)header_view.data + shm_tensorpool_control_messageHeader_encoded_length(),
        0,
        shm_tensorpool_control_tensorHeader_sbe_block_length(),
        shm_tensorpool_control_tensorHeader_sbe_schema_version(),
        header_len - shm_tensorpool_control_messageHeader_encoded_length());

    uint64_t end = __atomic_load_n(commit_ptr, __ATOMIC_ACQUIRE);
    if (begin != end || (end & 1ULL) != 0)
    {
        return TP_ERR_TIMEOUT;
    }
    if ((end >> 1) != consumer->last_seq)
    {
        return TP_ERR_PROTOCOL;
    }

    uint16_t pool_id = shm_tensorpool_control_slotHeader_poolId(&slot);
    tp_pool_mapping_t *pool = tp_consumer_find_pool(consumer, pool_id);
    if (pool == NULL)
    {
        return TP_ERR_PROTOCOL;
    }

    uint32_t values_len = shm_tensorpool_control_slotHeader_valuesLenBytes(&slot);
    uint32_t payload_slot = shm_tensorpool_control_slotHeader_payloadSlot(&slot);
    uint32_t payload_offset = shm_tensorpool_control_slotHeader_payloadOffset(&slot);
    uint64_t payload_pos = TP_SUPERBLOCK_SIZE + ((uint64_t)payload_slot * pool->stride_bytes) + payload_offset;
    if (payload_pos + values_len > pool->mapping.length)
    {
        return TP_ERR_PROTOCOL;
    }

    view->seq_commit = end;
    view->timestamp_ns = shm_tensorpool_control_slotHeader_timestampNs(&slot);
    view->values_len_bytes = values_len;
    view->payload_slot = payload_slot;
    view->pool_id = pool_id;
    view->payload_offset = payload_offset;
    view->meta_version = shm_tensorpool_control_slotHeader_metaVersion(&slot);
    view->payload = pool->mapping.addr + payload_pos;
    view->payload_len = values_len;
    enum shm_tensorpool_control_dtype dtype_val;
    if (!shm_tensorpool_control_tensorHeader_dtype(&tensor, &dtype_val))
    {
        return TP_ERR_PROTOCOL;
    }
    enum shm_tensorpool_control_majorOrder major_val;
    if (!shm_tensorpool_control_tensorHeader_majorOrder(&tensor, &major_val))
    {
        return TP_ERR_PROTOCOL;
    }
    view->tensor.dtype = (uint8_t)dtype_val;
    view->tensor.major_order = (uint8_t)major_val;
    view->tensor.ndims = shm_tensorpool_control_tensorHeader_ndims(&tensor);
    view->tensor.pad_align = shm_tensorpool_control_tensorHeader_padAlign(&tensor);
    enum shm_tensorpool_control_progressUnit progress_val;
    if (!shm_tensorpool_control_tensorHeader_progressUnit(&tensor, &progress_val))
    {
        return TP_ERR_PROTOCOL;
    }
    view->tensor.progress_unit = (uint8_t)progress_val;
    view->tensor.progress_stride_bytes = shm_tensorpool_control_tensorHeader_progressStrideBytes(&tensor);
    for (uint32_t i = 0; i < TP_MAX_DIMS; i++)
    {
        shm_tensorpool_control_tensorHeader_dims(&tensor, i, &view->tensor.dims[i]);
        shm_tensorpool_control_tensorHeader_strides(&tensor, i, &view->tensor.strides[i]);
    }
    consumer->has_descriptor = false;
    return TP_OK;
}

void tp_consumer_close(tp_consumer_t *consumer)
{
    if (consumer == NULL)
    {
        return;
    }
    if (consumer->descriptor_assembler)
    {
        aeron_fragment_assembler_delete(consumer->descriptor_assembler);
    }
    if (consumer->sub_descriptor)
    {
        aeron_subscription_close(consumer->sub_descriptor, NULL, NULL);
    }
    tp_shm_unmap(&consumer->header);
    for (uint32_t i = 0; i < consumer->pool_count; i++)
    {
        tp_shm_unmap(&consumer->pools[i].mapping);
    }
    free(consumer);
}

bool tp_consumer_is_connected(tp_consumer_t *consumer)
{
    if (consumer == NULL || consumer->sub_descriptor == NULL)
    {
        return false;
    }
    return aeron_subscription_is_connected(consumer->sub_descriptor);
}
