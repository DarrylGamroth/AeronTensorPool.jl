#include <assert.h>
#include <string.h>

#include "tp_internal.h"

static size_t tp_qos_producer_length(void)
{
    return shm_tensorpool_control_messageHeader_encoded_length() +
        shm_tensorpool_control_qosProducer_sbe_block_length();
}

static size_t tp_qos_consumer_length(void)
{
    return shm_tensorpool_control_messageHeader_encoded_length() +
        shm_tensorpool_control_qosConsumer_sbe_block_length();
}

int main(void)
{
    tp_qos_monitor_t monitor;
    memset(&monitor, 0, sizeof(monitor));

    char buffer[256];
    memset(buffer, 0, sizeof(buffer));

    struct shm_tensorpool_control_qosProducer qos_prod;
    struct shm_tensorpool_control_messageHeader header;
    shm_tensorpool_control_qosProducer_wrap_and_apply_header(&qos_prod, buffer, 0, sizeof(buffer), &header);
    shm_tensorpool_control_qosProducer_set_streamId(&qos_prod, 10000);
    shm_tensorpool_control_qosProducer_set_producerId(&qos_prod, 42);
    shm_tensorpool_control_qosProducer_set_epoch(&qos_prod, 7);
    shm_tensorpool_control_qosProducer_set_currentSeq(&qos_prod, 99);
    shm_tensorpool_control_qosProducer_set_watermark(&qos_prod, 88);
    tp_qos_monitor_handle_buffer(&monitor, buffer, tp_qos_producer_length());

    assert(monitor.producer_count == 1);
    assert(monitor.producers[0].producer_id == 42);
    assert(monitor.producers[0].stream_id == 10000);
    assert(monitor.producers[0].epoch == 7);
    assert(monitor.producers[0].current_seq == 99);
    assert(monitor.producers[0].watermark == 88);

    struct shm_tensorpool_control_qosConsumer qos_cons;
    memset(buffer, 0, sizeof(buffer));
    shm_tensorpool_control_qosConsumer_wrap_and_apply_header(&qos_cons, buffer, 0, sizeof(buffer), &header);
    shm_tensorpool_control_qosConsumer_set_streamId(&qos_cons, 10000);
    shm_tensorpool_control_qosConsumer_set_consumerId(&qos_cons, 77);
    shm_tensorpool_control_qosConsumer_set_epoch(&qos_cons, 5);
    shm_tensorpool_control_qosConsumer_set_mode(&qos_cons, shm_tensorpool_control_mode_STREAM);
    shm_tensorpool_control_qosConsumer_set_lastSeqSeen(&qos_cons, 1234);
    shm_tensorpool_control_qosConsumer_set_dropsGap(&qos_cons, 2);
    shm_tensorpool_control_qosConsumer_set_dropsLate(&qos_cons, 3);
    tp_qos_monitor_handle_buffer(&monitor, buffer, tp_qos_consumer_length());

    assert(monitor.consumer_count == 1);
    assert(monitor.consumers[0].consumer_id == 77);
    assert(monitor.consumers[0].stream_id == 10000);
    assert(monitor.consumers[0].epoch == 5);
    assert(monitor.consumers[0].mode == (uint8_t)shm_tensorpool_control_mode_STREAM);
    assert(monitor.consumers[0].last_seq_seen == 1234);
    assert(monitor.consumers[0].drops_gap == 2);
    assert(monitor.consumers[0].drops_late == 3);

    for (uint32_t i = 0; i < TP_MAX_QOS_ENTRIES + 4; i++)
    {
        memset(buffer, 0, sizeof(buffer));
        shm_tensorpool_control_qosProducer_wrap_and_apply_header(&qos_prod, buffer, 0, sizeof(buffer), &header);
        shm_tensorpool_control_qosProducer_set_streamId(&qos_prod, 10000);
        shm_tensorpool_control_qosProducer_set_producerId(&qos_prod, i + 1000);
        shm_tensorpool_control_qosProducer_set_epoch(&qos_prod, 1);
        shm_tensorpool_control_qosProducer_set_currentSeq(&qos_prod, i);
        shm_tensorpool_control_qosProducer_set_watermark(&qos_prod, 0);
        tp_qos_monitor_handle_buffer(&monitor, buffer, tp_qos_producer_length());
    }
    assert(monitor.producer_count == TP_MAX_QOS_ENTRIES);

    return 0;
}
