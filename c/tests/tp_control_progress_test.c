#include <assert.h>
#include <string.h>

#include "tp_internal.h"

static void encode_progress(
    uint8_t *buffer,
    size_t buffer_len,
    uint32_t stream_id,
    uint64_t epoch,
    uint64_t frame_id,
    uint32_t header_index,
    uint64_t bytes_filled,
    enum shm_tensorpool_control_frameProgressState state)
{
    struct shm_tensorpool_control_messageHeader hdr;
    struct shm_tensorpool_control_frameProgress msg;
    shm_tensorpool_control_frameProgress_wrap_and_apply_header(&msg, (char *)buffer, 0, buffer_len, &hdr);
    shm_tensorpool_control_frameProgress_set_streamId(&msg, stream_id);
    shm_tensorpool_control_frameProgress_set_epoch(&msg, epoch);
    shm_tensorpool_control_frameProgress_set_frameId(&msg, frame_id);
    shm_tensorpool_control_frameProgress_set_headerIndex(&msg, header_index);
    shm_tensorpool_control_frameProgress_set_payloadBytesFilled(&msg, bytes_filled);
    shm_tensorpool_control_frameProgress_set_state(&msg, state);
}

static uint64_t encode_announce(
    uint8_t *buffer,
    size_t buffer_len,
    uint32_t stream_id,
    uint64_t epoch,
    uint64_t announce_ts,
    enum shm_tensorpool_control_clockDomain domain)
{
    struct shm_tensorpool_control_messageHeader hdr;
    struct shm_tensorpool_control_shmPoolAnnounce msg;
    struct shm_tensorpool_control_shmPoolAnnounce_payloadPools pools;
    shm_tensorpool_control_shmPoolAnnounce_wrap_and_apply_header(&msg, (char *)buffer, 0, buffer_len, &hdr);
    shm_tensorpool_control_shmPoolAnnounce_set_streamId(&msg, stream_id);
    shm_tensorpool_control_shmPoolAnnounce_set_producerId(&msg, 1);
    shm_tensorpool_control_shmPoolAnnounce_set_epoch(&msg, epoch);
    shm_tensorpool_control_shmPoolAnnounce_set_layoutVersion(&msg, 1);
    shm_tensorpool_control_shmPoolAnnounce_set_headerNslots(&msg, 128);
    shm_tensorpool_control_shmPoolAnnounce_set_headerSlotBytes(&msg, 256);
    shm_tensorpool_control_shmPoolAnnounce_set_announceTimestampNs(&msg, announce_ts);
    shm_tensorpool_control_shmPoolAnnounce_set_announceClockDomain(&msg, domain);
    shm_tensorpool_control_shmPoolAnnounce_put_headerRegionUri(&msg, "", 0);
    shm_tensorpool_control_shmPoolAnnounce_payloadPools_set_count(&msg, &pools, 0);
    return shm_tensorpool_control_shmPoolAnnounce_encoded_length(&msg);
}

int main(void)
{
    tp_consumer_t consumer;
    memset(&consumer, 0, sizeof(consumer));
    consumer.stream_id = 10;
    consumer.epoch = 42;
    consumer.header_nslots = 8;
    tp_context_t context;
    memset(&context, 0, sizeof(context));
    context.announce_freshness_ns = 3000000000ULL;
    tp_client_t client;
    memset(&client, 0, sizeof(client));
    client.context = &context;
    consumer.client = &client;

    uint8_t buffer[512];

    memset(buffer, 0, sizeof(buffer));
    encode_progress(
        buffer,
        sizeof(buffer),
        consumer.stream_id,
        consumer.epoch,
        99,
        2,
        128,
        shm_tensorpool_control_frameProgressState_COMPLETE);
    tp_consumer_handle_control_buffer(&consumer, buffer,
        shm_tensorpool_control_messageHeader_encoded_length() +
        shm_tensorpool_control_frameProgress_sbe_block_length());
    assert(consumer.has_progress);
    assert(consumer.last_progress_frame_id == 99);
    assert(consumer.last_progress_header_index == 2);
    assert(consumer.last_progress_bytes == 128);

    consumer.has_progress = false;
    memset(buffer, 0, sizeof(buffer));
    encode_progress(
        buffer,
        sizeof(buffer),
        consumer.stream_id,
        consumer.epoch,
        100,
        99,
        256,
        shm_tensorpool_control_frameProgressState_COMPLETE);
    tp_consumer_handle_control_buffer(&consumer, buffer,
        shm_tensorpool_control_messageHeader_encoded_length() +
        shm_tensorpool_control_frameProgress_sbe_block_length());
    assert(!consumer.has_progress);

    consumer.join_time_ns = tp_now_ns();
    consumer.last_announce_timestamp_ns = 0;
    memset(buffer, 0, sizeof(buffer));
    encode_announce(
        buffer,
        sizeof(buffer),
        consumer.stream_id,
        consumer.epoch,
        consumer.join_time_ns - 1,
        shm_tensorpool_control_clockDomain_MONOTONIC);
    tp_consumer_handle_control_buffer(&consumer, buffer, sizeof(buffer));
    assert(consumer.last_announce_timestamp_ns == 0);

    uint64_t announce_ts = tp_now_ns();
    consumer.join_time_ns = announce_ts - 1;
    memset(buffer, 0, sizeof(buffer));
    uint64_t announce_len = encode_announce(
        buffer,
        sizeof(buffer),
        consumer.stream_id,
        consumer.epoch,
        announce_ts,
        shm_tensorpool_control_clockDomain_MONOTONIC);
    tp_consumer_handle_control_buffer(&consumer, buffer, announce_len);
    assert(consumer.last_announce_timestamp_ns == announce_ts);

    consumer.last_announce_timestamp_ns = 0;
    context.announce_freshness_ns = 1;
    announce_ts = tp_now_ns() - 5;
    memset(buffer, 0, sizeof(buffer));
    announce_len = encode_announce(
        buffer,
        sizeof(buffer),
        consumer.stream_id,
        consumer.epoch,
        announce_ts,
        shm_tensorpool_control_clockDomain_MONOTONIC);
    tp_consumer_handle_control_buffer(&consumer, buffer, announce_len);
    assert(consumer.last_announce_timestamp_ns == 0);

    context.announce_freshness_ns = 1000000000ULL;
    tp_consumer_handle_control_buffer(&consumer, buffer, announce_len);
    assert(consumer.last_announce_timestamp_ns == announce_ts);

    return 0;
}
