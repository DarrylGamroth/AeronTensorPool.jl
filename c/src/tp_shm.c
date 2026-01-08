#include "tp_internal.h"
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

#define TP_MAGIC_TPOLSHM1 0x544F504C53484D31ULL

static tp_err_t tp_parse_shm_path(const char *uri, const char **path_out)
{
    const char *prefix = "shm:file?path=";
    if (uri == NULL || strncmp(uri, prefix, strlen(prefix)) != 0)
    {
        return TP_ERR_ARG;
    }
    const char *path = uri + strlen(prefix);
    if (*path == '\0')
    {
        return TP_ERR_ARG;
    }
    *path_out = path;
    return TP_OK;
}

tp_err_t tp_shm_map(const char *uri, size_t size, bool write, tp_shm_mapping_t *mapping)
{
    if (uri == NULL || mapping == NULL || size == 0)
    {
        return TP_ERR_ARG;
    }
    const char *path = NULL;
    if (tp_parse_shm_path(uri, &path) != TP_OK)
    {
        return TP_ERR_ARG;
    }

    int flags = write ? O_RDWR : O_RDONLY;
    int fd = open(path, flags);
    if (fd < 0)
    {
        return TP_ERR_IO;
    }

    int prot = write ? (PROT_READ | PROT_WRITE) : PROT_READ;
    void *addr = mmap(NULL, size, prot, MAP_SHARED, fd, 0);
    close(fd);
    if (addr == MAP_FAILED)
    {
        return TP_ERR_IO;
    }

    mapping->addr = (uint8_t *)addr;
    mapping->length = size;
    return TP_OK;
}

void tp_shm_unmap(tp_shm_mapping_t *mapping)
{
    if (mapping == NULL || mapping->addr == NULL || mapping->length == 0)
    {
        return;
    }
    munmap(mapping->addr, mapping->length);
    mapping->addr = NULL;
    mapping->length = 0;
}

tp_err_t tp_shm_validate_superblock(
    const tp_shm_mapping_t *mapping,
    uint32_t expected_layout_version,
    uint64_t expected_epoch,
    uint32_t expected_stream_id,
    uint32_t expected_nslots,
    uint32_t expected_slot_bytes,
    uint32_t expected_stride_bytes,
    uint16_t expected_pool_id,
    uint16_t expected_region_type)
{
    if (mapping == NULL || mapping->addr == NULL || mapping->length < TP_SUPERBLOCK_SIZE)
    {
        return TP_ERR_ARG;
    }

    struct shm_tensorpool_control_shmRegionSuperblock sb;
    shm_tensorpool_control_shmRegionSuperblock_wrap_for_decode(
        &sb,
        (char *)mapping->addr,
        0,
        shm_tensorpool_control_shmRegionSuperblock_sbe_block_length(),
        shm_tensorpool_control_shmRegionSuperblock_sbe_schema_version(),
        mapping->length);

    uint64_t magic = shm_tensorpool_control_shmRegionSuperblock_magic(&sb);
    if (magic != TP_MAGIC_TPOLSHM1)
    {
        return TP_ERR_PROTOCOL;
    }
    if (shm_tensorpool_control_shmRegionSuperblock_layoutVersion(&sb) != expected_layout_version)
    {
        return TP_ERR_PROTOCOL;
    }
    if (shm_tensorpool_control_shmRegionSuperblock_epoch(&sb) != expected_epoch)
    {
        return TP_ERR_PROTOCOL;
    }
    if (shm_tensorpool_control_shmRegionSuperblock_streamId(&sb) != expected_stream_id)
    {
        return TP_ERR_PROTOCOL;
    }
    if (shm_tensorpool_control_shmRegionSuperblock_nslots(&sb) != expected_nslots)
    {
        return TP_ERR_PROTOCOL;
    }
    if (shm_tensorpool_control_shmRegionSuperblock_slotBytes(&sb) != expected_slot_bytes)
    {
        return TP_ERR_PROTOCOL;
    }
    if (expected_stride_bytes != 0 &&
        shm_tensorpool_control_shmRegionSuperblock_strideBytes(&sb) != expected_stride_bytes)
    {
        return TP_ERR_PROTOCOL;
    }
    if (shm_tensorpool_control_shmRegionSuperblock_poolId(&sb) != expected_pool_id)
    {
        return TP_ERR_PROTOCOL;
    }
    if ((uint16_t)shm_tensorpool_control_shmRegionSuperblock_regionType(&sb) != expected_region_type)
    {
        return TP_ERR_PROTOCOL;
    }
    return TP_OK;
}
