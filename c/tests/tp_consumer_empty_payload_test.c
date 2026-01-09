#include <assert.h>
#include <string.h>

#include "tensorpool_client.h"
#include "tp_internal.h"

static void encode_slot_header_empty(
    uint8_t *buffer,
    size_t buffer_len,
    uint32_t header_index,
    uint64_t seq_commit)
{
    size_t offset = TP_SUPERBLOCK_SIZE + ((size_t)header_index * 256);
    assert(buffer_len >= offset + 256);
    uint8_t *slot_buf = buffer + offset;
    struct shm_tensorpool_control_slotHeader slot;
    shm_tensorpool_control_slotHeader_wrap_for_encode(&slot, (char *)slot_buf, 0, buffer_len - offset);
    shm_tensorpool_control_slotHeader_set_seqCommit(&slot, seq_commit);
    shm_tensorpool_control_slotHeader_set_timestampNs(&slot, 0);
    shm_tensorpool_control_slotHeader_set_metaVersion(&slot, 0);
    shm_tensorpool_control_slotHeader_set_valuesLenBytes(&slot, 0);
    shm_tensorpool_control_slotHeader_set_payloadSlot(&slot, header_index);
    shm_tensorpool_control_slotHeader_set_payloadOffset(&slot, 0);
    shm_tensorpool_control_slotHeader_set_poolId(&slot, 1);

    uint64_t pos = shm_tensorpool_control_slotHeader_offset(&slot) +
        shm_tensorpool_control_slotHeader_sbe_block_length();
    shm_tensorpool_control_slotHeader_set_sbe_position(&slot, pos);
    uint32_t header_len = shm_tensorpool_control_messageHeader_encoded_length() +
        shm_tensorpool_control_tensorHeader_sbe_block_length();
    uint32_t header_len_le = SBE_LITTLE_ENDIAN_ENCODE_32(header_len);
    memcpy(slot_buf + pos, &header_len_le, sizeof(uint32_t));
    char *header_buf = (char *)(slot_buf + pos + 4);
    struct shm_tensorpool_control_messageHeader hdr;
    struct shm_tensorpool_control_tensorHeader tensor;
    shm_tensorpool_control_tensorHeader_wrap_and_apply_header(
        &tensor,
        header_buf,
        0,
        header_len,
        &hdr);
    shm_tensorpool_control_tensorHeader_set_dtype(&tensor, shm_tensorpool_control_dtype_UINT8);
    shm_tensorpool_control_tensorHeader_set_majorOrder(&tensor, shm_tensorpool_control_majorOrder_ROW);
    shm_tensorpool_control_tensorHeader_set_ndims(&tensor, 1);
    shm_tensorpool_control_tensorHeader_set_padAlign(&tensor, 0);
    shm_tensorpool_control_tensorHeader_set_progressUnit(&tensor, shm_tensorpool_control_progressUnit_NONE);
    shm_tensorpool_control_tensorHeader_set_progressStrideBytes(&tensor, 0);
    int32_t dims[TP_MAX_DIMS] = {0};
    int32_t strides[TP_MAX_DIMS] = {0};
    dims[0] = 1;
    strides[0] = 1;
    shm_tensorpool_control_tensorHeader_put_dims(&tensor, (const char *)dims);
    shm_tensorpool_control_tensorHeader_put_strides(&tensor, (const char *)strides);
    shm_tensorpool_control_slotHeader_set_sbe_position(&slot, pos + 4 + header_len);
}

int main(void)
{
    tp_context_t context;
    memset(&context, 0, sizeof(context));
    tp_client_t client;
    memset(&client, 0, sizeof(client));
    client.context = &context;

    tp_consumer_t consumer;
    memset(&consumer, 0, sizeof(consumer));
    consumer.client = &client;
    consumer.stream_id = 10;
    consumer.epoch = 42;
    consumer.last_epoch = 42;
    consumer.header_nslots = 8;
    consumer.header_slot_bytes = 256;
    consumer.pool_count = 1;
    consumer.has_descriptor = true;
    consumer.last_seq = 1;
    consumer.last_header_index = 1;

    uint8_t header_buf[TP_SUPERBLOCK_SIZE + (256 * 8)];
    memset(header_buf, 0, sizeof(header_buf));
    consumer.header.addr = header_buf;
    consumer.header.length = sizeof(header_buf);
    encode_slot_header_empty(header_buf, sizeof(header_buf), 1, (uint64_t)1 << 1);

    uint8_t payload_buf[TP_SUPERBLOCK_SIZE + (4096 * 8)];
    memset(payload_buf, 0, sizeof(payload_buf));
    consumer.pools[0].pool_id = 1;
    consumer.pools[0].nslots = 8;
    consumer.pools[0].stride_bytes = 4096;
    consumer.pools[0].mapping.addr = payload_buf;
    consumer.pools[0].mapping.length = sizeof(payload_buf);

    tp_frame_view_t view;
    memset(&view, 0, sizeof(view));
    tp_err_t err = tp_consumer_try_read_frame(&consumer, &view);
    assert(err == TP_OK);
    assert(view.values_len_bytes == 0);
    assert(view.payload_len == 0);
    return 0;
}
