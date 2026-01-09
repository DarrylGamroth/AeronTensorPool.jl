#include <assert.h>
#include <string.h>

#include "tp_internal.h"

int main(void)
{
    uint8_t buffer[TP_SUPERBLOCK_SIZE];
    memset(buffer, 0, sizeof(buffer));

    tp_shm_mapping_t mapping = { buffer, sizeof(buffer) };

    struct shm_tensorpool_control_shmRegionSuperblock sb;
    shm_tensorpool_control_shmRegionSuperblock_wrap_for_encode(&sb, (char *)buffer, 0, sizeof(buffer));

    shm_tensorpool_control_shmRegionSuperblock_set_magic(&sb, 0x544F504C53484D31ULL);
    shm_tensorpool_control_shmRegionSuperblock_set_layoutVersion(&sb, 1);
    shm_tensorpool_control_shmRegionSuperblock_set_epoch(&sb, 42);
    shm_tensorpool_control_shmRegionSuperblock_set_streamId(&sb, 7);
    shm_tensorpool_control_shmRegionSuperblock_set_regionType(&sb, shm_tensorpool_control_regionType_HEADER_RING);
    shm_tensorpool_control_shmRegionSuperblock_set_poolId(&sb, 0);
    shm_tensorpool_control_shmRegionSuperblock_set_nslots(&sb, 128);
    shm_tensorpool_control_shmRegionSuperblock_set_slotBytes(&sb, 256);
    shm_tensorpool_control_shmRegionSuperblock_set_strideBytes(&sb, 0);
    shm_tensorpool_control_shmRegionSuperblock_set_pid(&sb, 123);
    shm_tensorpool_control_shmRegionSuperblock_set_startTimestampNs(&sb, 100);
    shm_tensorpool_control_shmRegionSuperblock_set_activityTimestampNs(&sb, 200);

    tp_err_t err = tp_shm_validate_superblock(
        &mapping,
        1,
        42,
        7,
        128,
        256,
        0,
        0,
        shm_tensorpool_control_regionType_HEADER_RING);
    assert(err == TP_OK);

    shm_tensorpool_control_shmRegionSuperblock_set_magic(&sb, 0x0ULL);
    err = tp_shm_validate_superblock(
        &mapping,
        1,
        42,
        7,
        128,
        256,
        0,
        0,
        shm_tensorpool_control_regionType_HEADER_RING);
    assert(err == TP_ERR_PROTOCOL);

    shm_tensorpool_control_shmRegionSuperblock_set_magic(&sb, 0x544F504C53484D31ULL);
    shm_tensorpool_control_shmRegionSuperblock_set_layoutVersion(&sb, 2);
    err = tp_shm_validate_superblock(
        &mapping,
        1,
        42,
        7,
        128,
        256,
        0,
        0,
        shm_tensorpool_control_regionType_HEADER_RING);
    assert(err == TP_ERR_PROTOCOL);

    shm_tensorpool_control_shmRegionSuperblock_set_layoutVersion(&sb, 1);
    shm_tensorpool_control_shmRegionSuperblock_set_strideBytes(&sb, 512);
    err = tp_shm_validate_superblock(
        &mapping,
        1,
        42,
        7,
        128,
        256,
        1024,
        0,
        shm_tensorpool_control_regionType_HEADER_RING);
    assert(err == TP_ERR_PROTOCOL);

    shm_tensorpool_control_shmRegionSuperblock_set_strideBytes(&sb, 0);
    shm_tensorpool_control_shmRegionSuperblock_set_regionType(&sb, shm_tensorpool_control_regionType_PAYLOAD_POOL);
    err = tp_shm_validate_superblock(
        &mapping,
        1,
        42,
        7,
        128,
        256,
        0,
        0,
        shm_tensorpool_control_regionType_HEADER_RING);
    assert(err == TP_ERR_PROTOCOL);

    return 0;
}
