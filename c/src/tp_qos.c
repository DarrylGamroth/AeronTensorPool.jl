#include "tp_internal.h"
#include <stdio.h>

static tp_qos_producer_snapshot_t *tp_find_producer(tp_qos_monitor_t *monitor, uint32_t producer_id)
{
    for (uint32_t i = 0; i < monitor->producer_count; i++)
    {
        if (monitor->producers[i].producer_id == producer_id)
        {
            return &monitor->producers[i];
        }
    }
    return NULL;
}

static tp_qos_consumer_snapshot_t *tp_find_consumer(tp_qos_monitor_t *monitor, uint32_t consumer_id)
{
    for (uint32_t i = 0; i < monitor->consumer_count; i++)
    {
        if (monitor->consumers[i].consumer_id == consumer_id)
        {
            return &monitor->consumers[i];
        }
    }
    return NULL;
}

static void tp_qos_handle_producer(tp_qos_monitor_t *monitor, char *buffer, size_t length, struct shm_tensorpool_control_messageHeader *hdr)
{
    struct shm_tensorpool_control_qosProducer msg;
    const uint64_t acting_block_length = shm_tensorpool_control_messageHeader_blockLength(hdr);
    const uint64_t acting_version = shm_tensorpool_control_messageHeader_version(hdr);
    shm_tensorpool_control_qosProducer_wrap_for_decode(
        &msg,
        buffer + shm_tensorpool_control_messageHeader_encoded_length(),
        0,
        acting_block_length,
        acting_version,
        length - shm_tensorpool_control_messageHeader_encoded_length());

    uint32_t producer_id = shm_tensorpool_control_qosProducer_producerId(&msg);
    tp_qos_producer_snapshot_t *snap = tp_find_producer(monitor, producer_id);
    if (snap == NULL)
    {
        if (monitor->producer_count >= TP_MAX_QOS_ENTRIES)
        {
            return;
        }
        snap = &monitor->producers[monitor->producer_count++];
    }

    snap->stream_id = shm_tensorpool_control_qosProducer_streamId(&msg);
    snap->producer_id = producer_id;
    snap->epoch = shm_tensorpool_control_qosProducer_epoch(&msg);
    snap->current_seq = shm_tensorpool_control_qosProducer_currentSeq(&msg);
    snap->watermark = shm_tensorpool_control_qosProducer_watermark(&msg);
}

static void tp_qos_handle_consumer(tp_qos_monitor_t *monitor, char *buffer, size_t length, struct shm_tensorpool_control_messageHeader *hdr)
{
    struct shm_tensorpool_control_qosConsumer msg;
    const uint64_t acting_block_length = shm_tensorpool_control_messageHeader_blockLength(hdr);
    const uint64_t acting_version = shm_tensorpool_control_messageHeader_version(hdr);
    shm_tensorpool_control_qosConsumer_wrap_for_decode(
        &msg,
        buffer + shm_tensorpool_control_messageHeader_encoded_length(),
        0,
        acting_block_length,
        acting_version,
        length - shm_tensorpool_control_messageHeader_encoded_length());

    uint32_t consumer_id = shm_tensorpool_control_qosConsumer_consumerId(&msg);
    tp_qos_consumer_snapshot_t *snap = tp_find_consumer(monitor, consumer_id);
    if (snap == NULL)
    {
        if (monitor->consumer_count >= TP_MAX_QOS_ENTRIES)
        {
            return;
        }
        snap = &monitor->consumers[monitor->consumer_count++];
    }

    snap->stream_id = shm_tensorpool_control_qosConsumer_streamId(&msg);
    snap->consumer_id = consumer_id;
    snap->epoch = shm_tensorpool_control_qosConsumer_epoch(&msg);
    enum shm_tensorpool_control_mode mode_val;
    if (shm_tensorpool_control_qosConsumer_mode(&msg, &mode_val))
    {
        snap->mode = (uint8_t)mode_val;
    }
    else
    {
        snap->mode = 0;
    }
    snap->last_seq_seen = shm_tensorpool_control_qosConsumer_lastSeqSeen(&msg);
    snap->drops_gap = shm_tensorpool_control_qosConsumer_dropsGap(&msg);
    snap->drops_late = shm_tensorpool_control_qosConsumer_dropsLate(&msg);
}

static void tp_qos_handle_buffer(tp_qos_monitor_t *monitor, const uint8_t *buffer, size_t length)
{
    if (length < shm_tensorpool_control_messageHeader_encoded_length())
    {
        return;
    }
    char *buf = (char *)buffer;
    struct shm_tensorpool_control_messageHeader hdr;
    if (!shm_tensorpool_control_messageHeader_wrap(
            &hdr, buf, 0, shm_tensorpool_control_messageHeader_sbe_schema_version(), length))
    {
        return;
    }
    if (shm_tensorpool_control_messageHeader_version(&hdr) > shm_tensorpool_control_messageHeader_sbe_schema_version())
    {
        return;
    }
    uint16_t schema_id = shm_tensorpool_control_messageHeader_schemaId(&hdr);
    if (schema_id != shm_tensorpool_control_qosProducer_sbe_schema_id())
    {
        return;
    }
    uint16_t template_id = shm_tensorpool_control_messageHeader_templateId(&hdr);
    if (template_id == shm_tensorpool_control_qosProducer_sbe_template_id())
    {
        tp_qos_handle_producer(monitor, buf, length, &hdr);
    }
    else if (template_id == shm_tensorpool_control_qosConsumer_sbe_template_id())
    {
        tp_qos_handle_consumer(monitor, buf, length, &hdr);
    }
}

static void tp_qos_fragment_handler(void *clientd, const uint8_t *buffer, size_t length, aeron_header_t *header)
{
    (void)header;
    tp_qos_monitor_t *monitor = (tp_qos_monitor_t *)clientd;
    tp_qos_handle_buffer(monitor, buffer, length);
}

void tp_qos_monitor_handle_buffer(tp_qos_monitor_t *monitor, char *buffer, size_t length)
{
    if ((monitor == NULL) || (buffer == NULL))
    {
        return;
    }
    tp_qos_handle_buffer(monitor, (const uint8_t *)buffer, length);
}

tp_err_t tp_qos_monitor_init(tp_client_t *client, const char *channel, int32_t stream_id, tp_qos_monitor_t **monitor)
{
    if ((client == NULL) || (channel == NULL) || (monitor == NULL))
    {
        return TP_ERR_ARG;
    }
    tp_qos_monitor_t *state = (tp_qos_monitor_t *)calloc(1, sizeof(tp_qos_monitor_t));
    if (state == NULL)
    {
        return TP_ERR_NOMEM;
    }
    state->client = client;
    if (tp_add_subscription(client->aeron, channel, stream_id, &state->sub) < 0)
    {
        free(state);
        return TP_ERR_AERON;
    }
    if (aeron_fragment_assembler_create(&state->assembler, tp_qos_fragment_handler, state) < 0)
    {
        aeron_subscription_close(state->sub, NULL, NULL);
        free(state);
        return TP_ERR_AERON;
    }
    *monitor = state;
    return TP_OK;
}

void tp_qos_monitor_close(tp_qos_monitor_t *monitor)
{
    if (monitor == NULL)
    {
        return;
    }
    if (monitor->assembler)
    {
        aeron_fragment_assembler_delete(monitor->assembler);
    }
    if (monitor->sub)
    {
        aeron_subscription_close(monitor->sub, NULL, NULL);
    }
    free(monitor);
}

int tp_qos_monitor_poll(tp_qos_monitor_t *monitor, int fragment_limit)
{
    if (monitor == NULL)
    {
        return 0;
    }
    return aeron_subscription_poll(
        monitor->sub,
        aeron_fragment_assembler_handler,
        monitor->assembler,
        (size_t)fragment_limit);
}

tp_err_t tp_qos_monitor_get_producer(const tp_qos_monitor_t *monitor, uint32_t producer_id, tp_qos_producer_snapshot_t *out)
{
    if ((monitor == NULL) || (out == NULL))
    {
        return TP_ERR_ARG;
    }
    for (uint32_t i = 0; i < monitor->producer_count; i++)
    {
        if (monitor->producers[i].producer_id == producer_id)
        {
            *out = monitor->producers[i];
            return TP_OK;
        }
    }
    return TP_ERR_TIMEOUT;
}

tp_err_t tp_qos_monitor_get_consumer(const tp_qos_monitor_t *monitor, uint32_t consumer_id, tp_qos_consumer_snapshot_t *out)
{
    if ((monitor == NULL) || (out == NULL))
    {
        return TP_ERR_ARG;
    }
    for (uint32_t i = 0; i < monitor->consumer_count; i++)
    {
        if (monitor->consumers[i].consumer_id == consumer_id)
        {
            *out = monitor->consumers[i];
            return TP_OK;
        }
    }
    return TP_ERR_TIMEOUT;
}
