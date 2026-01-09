#include <assert.h>
#include <pthread.h>
#include <string.h>
#include <unistd.h>

#include "tensorpool_client.h"
#include "tp_internal.h"

static void write_slot_header(
    uint8_t *header_buf,
    size_t header_len,
    uint64_t header_offset,
    uint64_t seq_commit,
    uint32_t values_len,
    uint32_t payload_slot,
    uint32_t payload_offset,
    uint16_t pool_id)
{
    struct shm_tensorpool_control_slotHeader slot;
    shm_tensorpool_control_slotHeader_wrap_for_encode(
        &slot,
        (char *)header_buf + header_offset,
        0,
        header_len - header_offset);

    shm_tensorpool_control_slotHeader_set_seqCommit(&slot, seq_commit);
    shm_tensorpool_control_slotHeader_set_timestampNs(&slot, 0);
    shm_tensorpool_control_slotHeader_set_metaVersion(&slot, 0);
    shm_tensorpool_control_slotHeader_set_valuesLenBytes(&slot, values_len);
    shm_tensorpool_control_slotHeader_set_payloadSlot(&slot, payload_slot);
    shm_tensorpool_control_slotHeader_set_payloadOffset(&slot, payload_offset);
    shm_tensorpool_control_slotHeader_set_poolId(&slot, pool_id);

    uint8_t tensor_buf[256];
    struct shm_tensorpool_control_messageHeader hdr;
    struct shm_tensorpool_control_tensorHeader tensor;
    shm_tensorpool_control_messageHeader_wrap(
        &hdr,
        (char *)tensor_buf,
        0,
        shm_tensorpool_control_messageHeader_sbe_schema_version(),
        sizeof(tensor_buf));
    shm_tensorpool_control_messageHeader_set_blockLength(&hdr, shm_tensorpool_control_tensorHeader_sbe_block_length());
    shm_tensorpool_control_messageHeader_set_templateId(&hdr, shm_tensorpool_control_tensorHeader_sbe_template_id());
    shm_tensorpool_control_messageHeader_set_schemaId(&hdr, shm_tensorpool_control_tensorHeader_sbe_schema_id());
    shm_tensorpool_control_messageHeader_set_version(&hdr, shm_tensorpool_control_tensorHeader_sbe_schema_version());

    shm_tensorpool_control_tensorHeader_wrap_for_encode(
        &tensor,
        (char *)tensor_buf + shm_tensorpool_control_messageHeader_encoded_length(),
        0,
        sizeof(tensor_buf) - shm_tensorpool_control_messageHeader_encoded_length());
    shm_tensorpool_control_tensorHeader_set_dtype(&tensor, shm_tensorpool_control_dtype_UINT8);
    shm_tensorpool_control_tensorHeader_set_majorOrder(&tensor, shm_tensorpool_control_majorOrder_ROW);
    shm_tensorpool_control_tensorHeader_set_ndims(&tensor, 1);
    shm_tensorpool_control_tensorHeader_set_padAlign(&tensor, 0);
    shm_tensorpool_control_tensorHeader_set_progressUnit(&tensor, shm_tensorpool_control_progressUnit_NONE);
    shm_tensorpool_control_tensorHeader_set_progressStrideBytes(&tensor, 0);
    for (uint32_t i = 0; i < TP_MAX_DIMS; i++)
    {
        shm_tensorpool_control_tensorHeader_set_dims_unsafe(&tensor, i, i == 0 ? (int32_t)values_len : 0);
        shm_tensorpool_control_tensorHeader_set_strides_unsafe(&tensor, i, 0);
    }

    uint64_t tensor_len = shm_tensorpool_control_messageHeader_encoded_length() +
        shm_tensorpool_control_tensorHeader_sbe_block_length();
    struct shm_tensorpool_control_slotHeader *out =
        shm_tensorpool_control_slotHeader_put_headerBytes(&slot, (char *)tensor_buf, (uint32_t)tensor_len);
    assert(out != NULL);
}

static void init_consumer(tp_consumer_t *consumer, tp_client_t *client, uint8_t *header_buf, size_t header_len, uint8_t *payload_buf, size_t payload_len)
{
    memset(consumer, 0, sizeof(*consumer));
    consumer->client = client;
    consumer->lease_id = 1;
    consumer->stream_id = 10000;
    consumer->epoch = 1;
    consumer->last_epoch = 1;
    consumer->header_nslots = 8;
    consumer->header_slot_bytes = TP_HEADER_SLOT_BYTES;
    consumer->pool_count = 1;
    consumer->header.addr = header_buf;
    consumer->header.length = header_len;
    consumer->pools[0].pool_id = 1;
    consumer->pools[0].nslots = 8;
    consumer->pools[0].stride_bytes = 4096;
    consumer->pools[0].mapping.addr = payload_buf;
    consumer->pools[0].mapping.length = payload_len;
    consumer->has_descriptor = true;
    consumer->last_seq = 1;
    consumer->last_header_index = 1;
}

static void *flip_commit(void *arg)
{
    uint64_t *commit_ptr = (uint64_t *)arg;
    usleep(100);
    __atomic_store_n(commit_ptr, 2ULL << 1, __ATOMIC_RELEASE);
    return NULL;
}

int main(void)
{
    uint8_t header_buf[TP_SUPERBLOCK_SIZE + TP_HEADER_SLOT_BYTES * 8];
    uint8_t payload_buf[TP_SUPERBLOCK_SIZE + 4096 * 8];
    memset(header_buf, 0, sizeof(header_buf));
    memset(payload_buf, 0, sizeof(payload_buf));

    tp_client_t client;
    memset(&client, 0, sizeof(client));
    tp_consumer_t consumer;
    init_consumer(&consumer, &client, header_buf, sizeof(header_buf), payload_buf, sizeof(payload_buf));

    uint64_t header_offset = TP_SUPERBLOCK_SIZE + TP_HEADER_SLOT_BYTES;
    tp_frame_view_t view;

    write_slot_header(header_buf, sizeof(header_buf), header_offset, (1ULL << 1) | 1ULL, 16, 1, 0, 1);
    uint64_t *commit_ptr = (uint64_t *)(header_buf + header_offset);
    __atomic_store_n(commit_ptr, (1ULL << 1) | 1ULL, __ATOMIC_RELEASE);
    consumer.drops_late = 0;
    tp_err_t err = tp_consumer_try_read_frame(&consumer, &view);
    assert(err == TP_ERR_TIMEOUT);
    assert(consumer.drops_late == 1);

    bool saw_timeout = false;
    for (int attempt = 0; attempt < 100 && !saw_timeout; attempt++)
    {
        write_slot_header(header_buf, sizeof(header_buf), header_offset, (1ULL << 1), 16, 1, 0, 1);
        __atomic_store_n(commit_ptr, (1ULL << 1), __ATOMIC_RELEASE);
        pthread_t thread;
        pthread_create(&thread, NULL, flip_commit, commit_ptr);
        err = tp_consumer_try_read_frame(&consumer, &view);
        pthread_join(thread, NULL);
        if (err == TP_ERR_TIMEOUT)
        {
            saw_timeout = true;
        }
    }
    assert(saw_timeout);

    uint64_t header_offset2 = TP_SUPERBLOCK_SIZE + (TP_HEADER_SLOT_BYTES * 2);
    write_slot_header(header_buf, sizeof(header_buf), header_offset2, (3ULL << 1), 16, 2, 0, 1);
    uint64_t *commit_ptr2 = (uint64_t *)(header_buf + header_offset2);
    __atomic_store_n(commit_ptr2, (3ULL << 1), __ATOMIC_RELEASE);
    consumer.last_seq = 2;
    consumer.last_header_index = 2;
    consumer.revoked = false;
    err = tp_consumer_try_read_frame(&consumer, &view);
    assert(err == TP_ERR_PROTOCOL || err == TP_ERR_TIMEOUT);
    if (err == TP_ERR_PROTOCOL)
    {
        assert(consumer.revoked);
    }

    return 0;
}
