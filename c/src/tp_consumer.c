#include "tp_internal.h"
#include <stdio.h>

static const uint64_t TP_ANNOUNCE_FRESHNESS_NS = 3000000000ULL;

tp_err_t tp_consumer_send_qos(
    tp_consumer_t *consumer,
    uint8_t mode,
    uint64_t last_seq_seen,
    uint64_t drops_gap,
    uint64_t drops_late);

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
    if (shm_tensorpool_control_messageHeader_version(&hdr) > shm_tensorpool_control_messageHeader_sbe_schema_version())
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

    uint64_t next_seq = shm_tensorpool_control_frameDescriptor_seq(&desc);
    if (consumer->has_descriptor && next_seq > consumer->last_seq + 1)
    {
        consumer->drops_gap += (next_seq - consumer->last_seq - 1);
    }
    consumer->last_seq = next_seq;
    consumer->last_header_index = shm_tensorpool_control_frameDescriptor_headerIndex(&desc);
    consumer->last_meta_version = shm_tensorpool_control_frameDescriptor_metaVersion(&desc);
    consumer->last_epoch = shm_tensorpool_control_frameDescriptor_epoch(&desc);
    consumer->has_descriptor = true;
}

static void tp_consumer_control_handler(void *clientd, const uint8_t *buffer, size_t length, aeron_header_t *header)
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
    if (shm_tensorpool_control_messageHeader_version(&hdr) > shm_tensorpool_control_messageHeader_sbe_schema_version())
    {
        return;
    }
    uint16_t template_id = shm_tensorpool_control_messageHeader_templateId(&hdr);
    if (template_id == shm_tensorpool_control_consumerConfig_sbe_template_id())
    {
        struct shm_tensorpool_control_consumerConfig cfg;
        uint64_t acting_block_length = shm_tensorpool_control_messageHeader_blockLength(&hdr);
        uint64_t acting_version = shm_tensorpool_control_messageHeader_version(&hdr);
        shm_tensorpool_control_consumerConfig_wrap_for_decode(
            &cfg,
            (char *)buffer + shm_tensorpool_control_messageHeader_encoded_length(),
            0,
            acting_block_length,
            acting_version,
            length - shm_tensorpool_control_messageHeader_encoded_length());

        if (shm_tensorpool_control_consumerConfig_consumerId(&cfg) != consumer->client->context->client_id)
        {
            return;
        }
        if (shm_tensorpool_control_consumerConfig_streamId(&cfg) != consumer->stream_id)
        {
            return;
        }

        uint32_t desc_stream_id = shm_tensorpool_control_consumerConfig_descriptorStreamId(&cfg);
        struct shm_tensorpool_control_consumerConfig_string_view desc_view =
            shm_tensorpool_control_consumerConfig_get_descriptorChannel_as_string_view(&cfg);
        bool desc_has_channel = desc_view.length > 0;
        bool desc_has_stream = desc_stream_id != 0;
        if (desc_has_channel != desc_has_stream)
        {
            consumer->revoked = true;
            return;
        }
        if (desc_has_channel)
        {
            if (desc_view.length >= sizeof(consumer->descriptor_channel))
            {
                consumer->revoked = true;
                return;
            }
            memcpy(consumer->descriptor_channel, desc_view.data, desc_view.length);
            consumer->descriptor_channel[desc_view.length] = '\0';
            consumer->descriptor_stream_id = (int32_t)desc_stream_id;
            if (consumer->sub_descriptor)
            {
                aeron_subscription_close(consumer->sub_descriptor, NULL, NULL);
                consumer->sub_descriptor = NULL;
            }
            if (tp_add_subscription(consumer->client->aeron, consumer->descriptor_channel, consumer->descriptor_stream_id, &consumer->sub_descriptor) < 0)
            {
                consumer->revoked = true;
                return;
            }
        }

        uint32_t ctrl_stream_id = shm_tensorpool_control_consumerConfig_controlStreamId(&cfg);
        struct shm_tensorpool_control_consumerConfig_string_view ctrl_view =
            shm_tensorpool_control_consumerConfig_get_controlChannel_as_string_view(&cfg);
        bool ctrl_has_channel = ctrl_view.length > 0;
        bool ctrl_has_stream = ctrl_stream_id != 0;
        if (ctrl_has_channel != ctrl_has_stream)
        {
            consumer->revoked = true;
            return;
        }
        if (ctrl_has_channel)
        {
            if (ctrl_view.length >= sizeof(consumer->control_channel))
            {
                consumer->revoked = true;
                return;
            }
            memcpy(consumer->control_channel, ctrl_view.data, ctrl_view.length);
            consumer->control_channel[ctrl_view.length] = '\0';
            consumer->control_stream_id = (int32_t)ctrl_stream_id;
            if (consumer->sub_control)
            {
                aeron_subscription_close(consumer->sub_control, NULL, NULL);
                consumer->sub_control = NULL;
            }
            if (tp_add_subscription(consumer->client->aeron, consumer->control_channel, consumer->control_stream_id, &consumer->sub_control) < 0)
            {
                consumer->revoked = true;
                return;
            }
        }
        return;
    }

    if (template_id == shm_tensorpool_control_frameProgress_sbe_template_id())
    {
        struct shm_tensorpool_control_frameProgress progress;
        uint64_t acting_block_length = shm_tensorpool_control_messageHeader_blockLength(&hdr);
        uint64_t acting_version = shm_tensorpool_control_messageHeader_version(&hdr);
        shm_tensorpool_control_frameProgress_wrap_for_decode(
            &progress,
            (char *)buffer + shm_tensorpool_control_messageHeader_encoded_length(),
            0,
            acting_block_length,
            acting_version,
            length - shm_tensorpool_control_messageHeader_encoded_length());

        if (shm_tensorpool_control_frameProgress_streamId(&progress) != consumer->stream_id ||
            shm_tensorpool_control_frameProgress_epoch(&progress) != consumer->epoch)
        {
            return;
        }
        uint32_t header_index = shm_tensorpool_control_frameProgress_headerIndex(&progress);
        if (consumer->header_nslots > 0 && header_index >= consumer->header_nslots)
        {
            return;
        }
        enum shm_tensorpool_control_frameProgressState state_val;
        if (!shm_tensorpool_control_frameProgress_state(&progress, &state_val))
        {
            return;
        }
        consumer->last_progress_frame_id = shm_tensorpool_control_frameProgress_frameId(&progress);
        consumer->last_progress_header_index = header_index;
        consumer->last_progress_bytes = shm_tensorpool_control_frameProgress_payloadBytesFilled(&progress);
        consumer->last_progress_state = (uint8_t)state_val;
        consumer->has_progress = true;
        return;
    }

    if (template_id == shm_tensorpool_control_shmPoolAnnounce_sbe_template_id())
    {
        struct shm_tensorpool_control_shmPoolAnnounce announce;
        uint64_t acting_block_length = shm_tensorpool_control_messageHeader_blockLength(&hdr);
        uint64_t acting_version = shm_tensorpool_control_messageHeader_version(&hdr);
        shm_tensorpool_control_shmPoolAnnounce_wrap_for_decode(
            &announce,
            (char *)buffer + shm_tensorpool_control_messageHeader_encoded_length(),
            0,
            acting_block_length,
            acting_version,
            length - shm_tensorpool_control_messageHeader_encoded_length());

        if (shm_tensorpool_control_shmPoolAnnounce_streamId(&announce) != consumer->stream_id)
        {
            return;
        }
        if (shm_tensorpool_control_shmPoolAnnounce_epoch(&announce) != consumer->epoch)
        {
            return;
        }
        enum shm_tensorpool_control_clockDomain domain_val;
        if (!shm_tensorpool_control_shmPoolAnnounce_announceClockDomain(&announce, &domain_val))
        {
            return;
        }
        uint64_t announce_ts = shm_tensorpool_control_shmPoolAnnounce_announceTimestampNs(&announce);
        uint64_t now_ns = (domain_val == shm_tensorpool_control_clockDomain_REALTIME_SYNCED) ?
            tp_now_realtime_ns() : tp_now_ns();
        if (domain_val == shm_tensorpool_control_clockDomain_MONOTONIC &&
            announce_ts < consumer->join_time_ns)
        {
            return;
        }
        if (now_ns > announce_ts)
        {
            uint64_t delta = now_ns - announce_ts;
            if (delta > TP_ANNOUNCE_FRESHNESS_NS)
            {
                return;
            }
        }
        consumer->last_announce_timestamp_ns = announce_ts;
        consumer->last_announce_clock_domain = (uint8_t)domain_val;
        return;
    }
}

void tp_consumer_handle_control_buffer(tp_consumer_t *consumer, const uint8_t *buffer, size_t length)
{
    if (consumer == NULL || buffer == NULL)
    {
        return;
    }
    tp_consumer_control_handler(consumer, buffer, length, NULL);
}

static tp_err_t tp_consumer_protocol_error(tp_consumer_t *consumer)
{
    if (consumer != NULL)
    {
        consumer->revoked = true;
    }
    return TP_ERR_PROTOCOL;
}

static tp_err_t tp_consumer_send_hello(tp_consumer_t *consumer)
{
    if (consumer == NULL || consumer->pub_control == NULL)
    {
        return TP_ERR_ARG;
    }
    aeron_buffer_claim_t claim;
    uint64_t msg_len = shm_tensorpool_control_messageHeader_encoded_length() +
        shm_tensorpool_control_consumerHello_sbe_block_length() +
        shm_tensorpool_control_consumerHello_descriptorChannel_header_length() +
        shm_tensorpool_control_consumerHello_controlChannel_header_length();
    int64_t position = aeron_publication_try_claim(consumer->pub_control, msg_len, &claim);
    if (position < 0)
    {
        return TP_ERR_AERON;
    }

    struct shm_tensorpool_control_messageHeader hdr;
    struct shm_tensorpool_control_consumerHello hello;
    shm_tensorpool_control_consumerHello_wrap_and_apply_header(
        &hello,
        (char *)claim.data,
        0,
        msg_len,
        &hdr);

    shm_tensorpool_control_consumerHello_set_streamId(&hello, consumer->stream_id);
    shm_tensorpool_control_consumerHello_set_consumerId(&hello, consumer->client->context->client_id);
    shm_tensorpool_control_consumerHello_set_supportsShm(&hello, true);
    shm_tensorpool_control_consumerHello_set_supportsProgress(&hello, false);
    shm_tensorpool_control_consumerHello_set_mode(
        &hello,
        (enum shm_tensorpool_control_mode)consumer->client->context->consumer_mode);
    uint64_t max_rate = consumer->client->context->consumer_max_rate_hz;
    if (max_rate == 0)
    {
        max_rate = shm_tensorpool_control_consumerHello_maxRateHz_null_value();
    }
    shm_tensorpool_control_consumerHello_set_maxRateHz(&hello, max_rate);
    shm_tensorpool_control_consumerHello_set_progressIntervalUs(
        &hello,
        shm_tensorpool_control_consumerHello_progressIntervalUs_null_value());
    shm_tensorpool_control_consumerHello_set_progressMajorDeltaUnits(
        &hello,
        shm_tensorpool_control_consumerHello_progressMajorDeltaUnits_null_value());
    if (consumer->client->context->consumer_descriptor_stream_id != 0 &&
        consumer->client->context->consumer_descriptor_channel[0] != '\0')
    {
        shm_tensorpool_control_consumerHello_set_descriptorStreamId(
            &hello,
            (uint32_t)consumer->client->context->consumer_descriptor_stream_id);
        shm_tensorpool_control_consumerHello_put_descriptorChannel(
            &hello,
            consumer->client->context->consumer_descriptor_channel,
            (uint32_t)strlen(consumer->client->context->consumer_descriptor_channel));
    }
    else
    {
        shm_tensorpool_control_consumerHello_set_descriptorStreamId(&hello, 0);
        shm_tensorpool_control_consumerHello_put_descriptorChannel(&hello, "", 0);
    }
    if (consumer->client->context->consumer_control_stream_id != 0 &&
        consumer->client->context->consumer_control_channel[0] != '\0')
    {
        shm_tensorpool_control_consumerHello_set_controlStreamId(
            &hello,
            (uint32_t)consumer->client->context->consumer_control_stream_id);
        shm_tensorpool_control_consumerHello_put_controlChannel(
            &hello,
            consumer->client->context->consumer_control_channel,
            (uint32_t)strlen(consumer->client->context->consumer_control_channel));
    }
    else
    {
        shm_tensorpool_control_consumerHello_set_controlStreamId(&hello, 0);
        shm_tensorpool_control_consumerHello_put_controlChannel(&hello, "", 0);
    }

    aeron_buffer_claim_commit(&claim);
    return TP_OK;
}

static bool tp_is_power_of_two(uint32_t value)
{
    return value != 0 && (value & (value - 1)) == 0;
}

static uint32_t tp_dtype_size(enum shm_tensorpool_control_dtype dtype)
{
    switch (dtype)
    {
        case shm_tensorpool_control_dtype_UINT8:
        case shm_tensorpool_control_dtype_INT8:
        case shm_tensorpool_control_dtype_BOOLEAN:
        case shm_tensorpool_control_dtype_BYTES:
        case shm_tensorpool_control_dtype_BIT:
            return 1;
        case shm_tensorpool_control_dtype_UINT16:
        case shm_tensorpool_control_dtype_INT16:
            return 2;
        case shm_tensorpool_control_dtype_UINT32:
        case shm_tensorpool_control_dtype_INT32:
        case shm_tensorpool_control_dtype_FLOAT32:
            return 4;
        case shm_tensorpool_control_dtype_UINT64:
        case shm_tensorpool_control_dtype_INT64:
        case shm_tensorpool_control_dtype_FLOAT64:
            return 8;
        default:
            return 0;
    }
}

static bool tp_infer_strides(
    uint8_t major_order,
    uint8_t ndims,
    const int32_t *dims,
    uint32_t elem_size,
    int32_t *out_strides)
{
    if (ndims == 0 || elem_size == 0)
    {
        return false;
    }
    if (major_order == shm_tensorpool_control_majorOrder_ROW)
    {
        out_strides[ndims - 1] = (int32_t)elem_size;
        for (int32_t i = (int32_t)ndims - 2; i >= 0; i--)
        {
            if (dims[i + 1] <= 0)
            {
                return false;
            }
            out_strides[i] = out_strides[i + 1] * dims[i + 1];
        }
    }
    else if (major_order == shm_tensorpool_control_majorOrder_COLUMN)
    {
        out_strides[0] = (int32_t)elem_size;
        for (uint32_t i = 1; i < ndims; i++)
        {
            if (dims[i - 1] <= 0)
            {
                return false;
            }
            out_strides[i] = out_strides[i - 1] * dims[i - 1];
        }
    }
    else
    {
        return false;
    }
    return true;
}

static bool tp_validate_strides(
    uint8_t major_order,
    uint8_t ndims,
    const int32_t *dims,
    const int32_t *strides)
{
    if (ndims == 0)
    {
        return false;
    }
    if (major_order == shm_tensorpool_control_majorOrder_ROW)
    {
        for (uint32_t i = 0; i + 1 < ndims; i++)
        {
            if (dims[i + 1] <= 0)
            {
                return false;
            }
            if (strides[i] < strides[i + 1] * dims[i + 1])
            {
                return false;
            }
        }
    }
    else if (major_order == shm_tensorpool_control_majorOrder_COLUMN)
    {
        for (uint32_t i = 1; i < ndims; i++)
        {
            if (dims[i - 1] <= 0)
            {
                return false;
            }
            if (strides[i] < strides[i - 1] * dims[i - 1])
            {
                return false;
            }
        }
    }
    else
    {
        return false;
    }
    return true;
}

static bool tp_validate_tensor_layout(
    uint8_t major_order,
    uint8_t ndims,
    enum shm_tensorpool_control_progressUnit progress_unit,
    uint32_t progress_stride_bytes,
    uint32_t elem_size,
    const int32_t *dims,
    const int32_t *strides,
    int32_t *out_strides)
{
    if (ndims == 0 || ndims > TP_MAX_DIMS || elem_size == 0)
    {
        return false;
    }
    bool all_zero = true;
    bool any_zero = false;
    for (uint32_t i = 0; i < ndims; i++)
    {
        if (dims[i] <= 0)
        {
            return false;
        }
        if (strides[i] == 0)
        {
            any_zero = true;
        }
        else if (strides[i] < 0)
        {
            return false;
        }
        else
        {
            all_zero = false;
        }
    }
    if (any_zero && !all_zero)
    {
        return false;
    }
    if (all_zero)
    {
        if (!tp_infer_strides(major_order, ndims, dims, elem_size, out_strides))
        {
            return false;
        }
    }
    else
    {
        for (uint32_t i = 0; i < ndims; i++)
        {
            out_strides[i] = strides[i];
        }
        if (!tp_validate_strides(major_order, ndims, dims, out_strides))
        {
            return false;
        }
    }

    if (progress_unit != shm_tensorpool_control_progressUnit_NONE)
    {
        uint32_t expected_stride = 0;
        if (progress_unit == shm_tensorpool_control_progressUnit_ROWS)
        {
            expected_stride = (uint32_t)out_strides[0];
        }
        else if (progress_unit == shm_tensorpool_control_progressUnit_COLUMNS)
        {
            if (ndims < 2)
            {
                return false;
            }
            expected_stride = (uint32_t)out_strides[1];
        }
        else
        {
            return false;
        }
        if (expected_stride == 0 || progress_stride_bytes != expected_stride)
        {
            return false;
        }
    }
    return true;
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
    if (!tp_is_power_of_two(resp->header_nslots))
    {
        tp_consumer_close(consumer);
        return TP_ERR_PROTOCOL;
    }
    snprintf(consumer->descriptor_channel, sizeof(consumer->descriptor_channel), "%s", client->context->descriptor_channel);
    consumer->descriptor_stream_id = client->context->descriptor_stream_id;
    snprintf(consumer->control_channel, sizeof(consumer->control_channel), "%s", client->context->control_channel);
    consumer->control_stream_id = client->context->control_stream_id;

    bool require_hugepages = false;
    if (tp_shm_validate_uri(resp->header_uri, &require_hugepages) != TP_OK)
    {
        tp_consumer_close(consumer);
        return TP_ERR_PROTOCOL;
    }
    if (require_hugepages)
    {
        tp_consumer_close(consumer);
        return TP_ERR_UNSUPPORTED;
    }

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
        require_hugepages = false;
        if (tp_shm_validate_uri(resp->pools[i].uri, &require_hugepages) != TP_OK)
        {
            tp_consumer_close(consumer);
            return TP_ERR_PROTOCOL;
        }
        if (tp_validate_stride_bytes(resp->pools[i].stride_bytes, require_hugepages) != TP_OK)
        {
            tp_consumer_close(consumer);
            return TP_ERR_PROTOCOL;
        }
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

    if (tp_add_subscription(client->aeron, consumer->descriptor_channel, consumer->descriptor_stream_id, &consumer->sub_descriptor) < 0)
    {
        tp_consumer_close(consumer);
        return TP_ERR_AERON;
    }
    if (aeron_fragment_assembler_create(&consumer->descriptor_assembler, tp_descriptor_handler, consumer) < 0)
    {
        tp_consumer_close(consumer);
        return TP_ERR_AERON;
    }
    if (tp_add_publication(client->aeron, consumer->control_channel, consumer->control_stream_id, &consumer->pub_control) < 0)
    {
        tp_consumer_close(consumer);
        return TP_ERR_AERON;
    }
    if (tp_add_subscription(client->aeron, consumer->control_channel, consumer->control_stream_id, &consumer->sub_control) < 0)
    {
        tp_consumer_close(consumer);
        return TP_ERR_AERON;
    }
    if (aeron_fragment_assembler_create(&consumer->control_assembler, tp_consumer_control_handler, consumer) < 0)
    {
        tp_consumer_close(consumer);
        return TP_ERR_AERON;
    }
    if (client->context->qos_channel[0] != '\0' && client->context->qos_stream_id != 0)
    {
        if (tp_add_publication(client->aeron, client->context->qos_channel, client->context->qos_stream_id, &consumer->pub_qos) < 0)
        {
            tp_consumer_close(consumer);
            return TP_ERR_AERON;
        }
    }

    consumer->last_qos_ns = tp_now_ns();
    consumer->last_keepalive_ns = consumer->last_qos_ns;
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
    if (resp.stream_id != stream_id)
    {
        return TP_ERR_PROTOCOL;
    }
    tp_err_t init_err = tp_init_consumer_from_attach(client, &resp, consumer);
    if (init_err != TP_OK)
    {
        return init_err;
    }
    (*consumer)->join_time_ns = tp_now_ns();
    return tp_consumer_send_hello(*consumer);
}

tp_err_t tp_consumer_reattach(tp_consumer_t **consumer)
{
    if (consumer == NULL || *consumer == NULL)
    {
        return TP_ERR_ARG;
    }
    tp_client_t *client = (*consumer)->client;
    uint32_t stream_id = (*consumer)->stream_id;
    tp_consumer_close(*consumer);
    *consumer = NULL;
    return tp_attach_consumer(client, stream_id, consumer);
}

tp_err_t tp_consumer_poll(tp_consumer_t *consumer, int fragment_limit)
{
    if (consumer == NULL || consumer->sub_descriptor == NULL)
    {
        return TP_ERR_ARG;
    }
    if (consumer->revoked || consumer->client->driver.shutdown)
    {
        consumer->revoked = true;
        return TP_ERR_PROTOCOL;
    }
    if (consumer->client->driver.revoked_lease_id == consumer->lease_id &&
        consumer->client->driver.revoked_role == shm_tensorpool_driver_role_CONSUMER)
    {
        consumer->revoked = true;
        return TP_ERR_PROTOCOL;
    }
    if (consumer->sub_control)
    {
        aeron_subscription_poll(
            consumer->sub_control,
            aeron_fragment_assembler_handler,
            consumer->control_assembler,
            (size_t)fragment_limit);
    }
    aeron_subscription_poll(
        consumer->sub_descriptor,
        aeron_fragment_assembler_handler,
        consumer->descriptor_assembler,
        (size_t)fragment_limit);
    uint64_t now_ns = tp_now_ns();
    uint64_t keepalive_interval = consumer->client->context->lease_keepalive_interval_ns;
    if (keepalive_interval > 0 && now_ns - consumer->last_keepalive_ns >= keepalive_interval)
    {
        tp_err_t err = tp_lease_keepalive(
            consumer->client,
            consumer->lease_id,
            consumer->stream_id,
            consumer->client->context->client_id,
            shm_tensorpool_driver_role_CONSUMER);
        if (err != TP_OK)
        {
            consumer->revoked = true;
            return TP_ERR_PROTOCOL;
        }
        consumer->last_keepalive_ns = now_ns;
    }
    if (consumer->pub_qos != NULL && consumer->client != NULL)
    {
        if (now_ns - consumer->last_qos_ns >= consumer->client->context->qos_interval_ns)
        {
            tp_consumer_send_qos(
                consumer,
                consumer->client->context->consumer_mode,
                consumer->last_seq,
                consumer->drops_gap,
                consumer->drops_late);
            consumer->last_qos_ns = now_ns;
        }
    }
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
    if (consumer->revoked || consumer->client->driver.shutdown)
    {
        return tp_consumer_protocol_error(consumer);
    }
    if (consumer->client->driver.revoked_lease_id == consumer->lease_id &&
        consumer->client->driver.revoked_role == shm_tensorpool_driver_role_CONSUMER)
    {
        consumer->revoked = true;
        return tp_consumer_protocol_error(consumer);
    }
    if (consumer->client->driver.revoked_role == shm_tensorpool_driver_role_PRODUCER &&
        consumer->client->driver.revoked_stream_id == consumer->stream_id)
    {
        consumer->revoked = true;
        return tp_consumer_protocol_error(consumer);
    }
    if (!consumer->has_descriptor)
    {
        return TP_ERR_TIMEOUT;
    }
    if (consumer->last_epoch != consumer->epoch)
    {
        consumer->revoked = true;
        return tp_consumer_protocol_error(consumer);
    }

    uint32_t header_index = consumer->last_header_index;
    if (header_index >= consumer->header_nslots)
    {
        return tp_consumer_protocol_error(consumer);
    }
    if (tp_is_power_of_two(consumer->header_nslots))
    {
        if ((consumer->last_seq & (consumer->header_nslots - 1)) != header_index)
        {
            return tp_consumer_protocol_error(consumer);
        }
    }
    uint64_t header_offset = TP_SUPERBLOCK_SIZE + ((uint64_t)header_index * consumer->header_slot_bytes);
    uint64_t *commit_ptr = (uint64_t *)(consumer->header.addr + header_offset);
    uint64_t begin = __atomic_load_n(commit_ptr, __ATOMIC_ACQUIRE);
    if ((begin & 1ULL) != 0)
    {
        consumer->drops_late += 1;
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
        return tp_consumer_protocol_error(consumer);
    }
    uint32_t header_len = header_view.length;
    if (header_len != (shm_tensorpool_control_messageHeader_encoded_length() +
        shm_tensorpool_control_tensorHeader_sbe_block_length()))
    {
        if (getenv("TP_DEBUG_FRAME") != NULL)
        {
            fprintf(stderr, "headerBytes length mismatch: %u\n", header_len);
        }
        return tp_consumer_protocol_error(consumer);
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
        return tp_consumer_protocol_error(consumer);
    }
    if (shm_tensorpool_control_messageHeader_version(&hdr) > shm_tensorpool_control_messageHeader_sbe_schema_version())
    {
        return tp_consumer_protocol_error(consumer);
    }
    if (shm_tensorpool_control_messageHeader_templateId(&hdr) != shm_tensorpool_control_tensorHeader_sbe_template_id())
    {
        if (getenv("TP_DEBUG_FRAME") != NULL)
        {
            fprintf(stderr, "tensorHeader template mismatch: %u\n",
                shm_tensorpool_control_messageHeader_templateId(&hdr));
        }
        return tp_consumer_protocol_error(consumer);
    }
    if (shm_tensorpool_control_messageHeader_blockLength(&hdr) != shm_tensorpool_control_tensorHeader_sbe_block_length())
    {
        if (getenv("TP_DEBUG_FRAME") != NULL)
        {
            fprintf(stderr, "tensorHeader block length mismatch: %u\n",
                shm_tensorpool_control_messageHeader_blockLength(&hdr));
        }
        return tp_consumer_protocol_error(consumer);
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
        consumer->drops_late += 1;
        return TP_ERR_TIMEOUT;
    }
    if ((end >> 1) != consumer->last_seq)
    {
        consumer->drops_late += 1;
        return tp_consumer_protocol_error(consumer);
    }

    uint16_t pool_id = shm_tensorpool_control_slotHeader_poolId(&slot);
    tp_pool_mapping_t *pool = tp_consumer_find_pool(consumer, pool_id);
    if (pool == NULL)
    {
        return tp_consumer_protocol_error(consumer);
    }

    uint32_t values_len = shm_tensorpool_control_slotHeader_valuesLenBytes(&slot);
    uint32_t payload_slot = shm_tensorpool_control_slotHeader_payloadSlot(&slot);
    uint32_t payload_offset = shm_tensorpool_control_slotHeader_payloadOffset(&slot);
    if (payload_offset != 0)
    {
        return tp_consumer_protocol_error(consumer);
    }
    if (payload_slot >= pool->nslots)
    {
        return tp_consumer_protocol_error(consumer);
    }
    if (values_len > pool->stride_bytes)
    {
        return tp_consumer_protocol_error(consumer);
    }
    uint64_t payload_pos = TP_SUPERBLOCK_SIZE + ((uint64_t)payload_slot * pool->stride_bytes) + payload_offset;
    if (payload_pos + values_len > pool->mapping.length)
    {
        return tp_consumer_protocol_error(consumer);
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
        return tp_consumer_protocol_error(consumer);
    }
    if (dtype_val == shm_tensorpool_control_dtype_NULL_VALUE)
    {
        return tp_consumer_protocol_error(consumer);
    }
    enum shm_tensorpool_control_majorOrder major_val;
    if (!shm_tensorpool_control_tensorHeader_majorOrder(&tensor, &major_val))
    {
        return tp_consumer_protocol_error(consumer);
    }
    if (major_val == shm_tensorpool_control_majorOrder_NULL_VALUE)
    {
        return tp_consumer_protocol_error(consumer);
    }
    view->tensor.dtype = (uint8_t)dtype_val;
    view->tensor.major_order = (uint8_t)major_val;
    view->tensor.ndims = shm_tensorpool_control_tensorHeader_ndims(&tensor);
    view->tensor.pad_align = shm_tensorpool_control_tensorHeader_padAlign(&tensor);
    enum shm_tensorpool_control_progressUnit progress_val;
    if (!shm_tensorpool_control_tensorHeader_progressUnit(&tensor, &progress_val))
    {
        return tp_consumer_protocol_error(consumer);
    }
    if (progress_val == shm_tensorpool_control_progressUnit_NULL_VALUE)
    {
        return tp_consumer_protocol_error(consumer);
    }
    view->tensor.progress_unit = (uint8_t)progress_val;
    view->tensor.progress_stride_bytes = shm_tensorpool_control_tensorHeader_progressStrideBytes(&tensor);
    for (uint32_t i = 0; i < TP_MAX_DIMS; i++)
    {
        shm_tensorpool_control_tensorHeader_dims(&tensor, i, &view->tensor.dims[i]);
        shm_tensorpool_control_tensorHeader_strides(&tensor, i, &view->tensor.strides[i]);
    }
    if (view->tensor.ndims == 0 || view->tensor.ndims > TP_MAX_DIMS)
    {
        return tp_consumer_protocol_error(consumer);
    }
    int32_t resolved_strides[TP_MAX_DIMS] = {0};
    uint32_t elem_size = tp_dtype_size(dtype_val);
    if (elem_size == 0)
    {
        return tp_consumer_protocol_error(consumer);
    }
    if (!tp_validate_tensor_layout(
            view->tensor.major_order,
            view->tensor.ndims,
            progress_val,
            view->tensor.progress_stride_bytes,
            elem_size,
            view->tensor.dims,
            view->tensor.strides,
            resolved_strides))
    {
        return tp_consumer_protocol_error(consumer);
    }
    consumer->has_descriptor = false;
    return TP_OK;
}

tp_err_t tp_consumer_send_qos(
    tp_consumer_t *consumer,
    uint8_t mode,
    uint64_t last_seq_seen,
    uint64_t drops_gap,
    uint64_t drops_late)
{
    if (consumer == NULL || consumer->pub_qos == NULL)
    {
        return TP_ERR_ARG;
    }
    aeron_buffer_claim_t claim_buf;
    uint64_t msg_len = shm_tensorpool_control_messageHeader_encoded_length() +
        shm_tensorpool_control_qosConsumer_sbe_block_length();
    int64_t position = aeron_publication_try_claim(consumer->pub_qos, msg_len, &claim_buf);
    if (position < 0)
    {
        return TP_ERR_AERON;
    }

    struct shm_tensorpool_control_messageHeader hdr;
    struct shm_tensorpool_control_qosConsumer msg;
    shm_tensorpool_control_qosConsumer_wrap_and_apply_header(
        &msg,
        (char *)claim_buf.data,
        0,
        msg_len,
        &hdr);
    shm_tensorpool_control_qosConsumer_set_streamId(&msg, consumer->stream_id);
    shm_tensorpool_control_qosConsumer_set_consumerId(&msg, consumer->client->context->client_id);
    shm_tensorpool_control_qosConsumer_set_epoch(&msg, consumer->epoch);
    shm_tensorpool_control_qosConsumer_set_mode(&msg, (enum shm_tensorpool_control_mode)mode);
    shm_tensorpool_control_qosConsumer_set_lastSeqSeen(&msg, last_seq_seen);
    shm_tensorpool_control_qosConsumer_set_dropsGap(&msg, drops_gap);
    shm_tensorpool_control_qosConsumer_set_dropsLate(&msg, drops_late);

    aeron_buffer_claim_commit(&claim_buf);
    return TP_OK;
}

bool tp_consumer_get_progress(tp_consumer_t *consumer, uint64_t *frame_id, uint64_t *bytes_filled, uint8_t *state)
{
    if (consumer == NULL || frame_id == NULL || bytes_filled == NULL || state == NULL)
    {
        return false;
    }
    if (!consumer->has_progress)
    {
        return false;
    }
    *frame_id = consumer->last_progress_frame_id;
    *bytes_filled = consumer->last_progress_bytes;
    *state = consumer->last_progress_state;
    return true;
}

void tp_consumer_close(tp_consumer_t *consumer)
{
    if (consumer == NULL)
    {
        return;
    }
    if (consumer->control_assembler)
    {
        aeron_fragment_assembler_delete(consumer->control_assembler);
    }
    if (consumer->descriptor_assembler)
    {
        aeron_fragment_assembler_delete(consumer->descriptor_assembler);
    }
    if (consumer->sub_control)
    {
        aeron_subscription_close(consumer->sub_control, NULL, NULL);
    }
    if (consumer->sub_descriptor)
    {
        aeron_subscription_close(consumer->sub_descriptor, NULL, NULL);
    }
    if (consumer->pub_control)
    {
        aeron_publication_close(consumer->pub_control, NULL, NULL);
    }
    if (consumer->pub_qos)
    {
        aeron_publication_close(consumer->pub_qos, NULL, NULL);
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
