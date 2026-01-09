#include "tp_internal.h"
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

#define TP_MAGIC_TPOLSHM1 0x544F504C53484D31ULL

static bool tp_is_power_of_two(uint32_t value)
{
    return value != 0 && (value & (value - 1)) == 0;
}

static tp_err_t tp_parse_shm_uri(const char *uri, char *path_out, size_t path_len, bool *require_hugepages)
{
    const char *prefix = "shm:file?";
    if ((uri == NULL) || (path_out == NULL) || (path_len == 0) || (require_hugepages == NULL))
    {
        return TP_ERR_ARG;
    }
    if (strncmp(uri, prefix, strlen(prefix)) != 0)
    {
        return TP_ERR_PROTOCOL;
    }

    const char *params = uri + strlen(prefix);
    if (*params == '\0')
    {
        return TP_ERR_PROTOCOL;
    }

    *require_hugepages = false;
    bool have_path = false;
    const char *cursor = params;
    while (*cursor != '\0')
    {
        const char *sep = strchr(cursor, '|');
        size_t part_len = sep ? (size_t)(sep - cursor) : strlen(cursor);
        const char *eq = memchr(cursor, '=', part_len);
        if ((eq == NULL) || (eq == cursor))
        {
            return TP_ERR_PROTOCOL;
        }
        size_t key_len = (size_t)(eq - cursor);
        size_t val_len = part_len - key_len - 1;
        const char *val = eq + 1;

        if (key_len == 4 && strncmp(cursor, "path", 4) == 0)
        {
            if ((val_len == 0) || (val_len >= path_len))
            {
                return TP_ERR_PROTOCOL;
            }
            memcpy(path_out, val, val_len);
            path_out[val_len] = '\0';
            have_path = true;
        }
        else if (key_len == 17 && strncmp(cursor, "require_hugepages", 17) == 0)
        {
            if ((val_len == 4) && (strncmp(val, "true", 4) == 0))
            {
                *require_hugepages = true;
            }
            else if ((val_len == 5) && (strncmp(val, "false", 5) == 0))
            {
                *require_hugepages = false;
            }
            else
            {
                return TP_ERR_PROTOCOL;
            }
        }
        else
        {
            return TP_ERR_PROTOCOL;
        }

        if (!sep)
        {
            break;
        }
        cursor = sep + 1;
    }

    if ((!have_path) || (path_out[0] == '\0') || (path_out[0] != '/'))
    {
        return TP_ERR_PROTOCOL;
    }

    return TP_OK;
}

tp_err_t tp_shm_validate_uri(const char *uri, bool *require_hugepages)
{
    char path_buf[TP_URI_MAX];
    return tp_parse_shm_uri(uri, path_buf, sizeof(path_buf), require_hugepages);
}

tp_err_t tp_validate_stride_bytes(uint32_t stride_bytes, bool require_hugepages)
{
    if (stride_bytes == 0)
    {
        return TP_ERR_PROTOCOL;
    }
    if (!tp_is_power_of_two(stride_bytes))
    {
        return TP_ERR_PROTOCOL;
    }
    long page_size = sysconf(_SC_PAGESIZE);
    if ((page_size > 0) && ((stride_bytes % (uint32_t)page_size) != 0))
    {
        return TP_ERR_PROTOCOL;
    }
    if (require_hugepages)
    {
        return TP_ERR_UNSUPPORTED;
    }
    return TP_OK;
}

tp_err_t tp_shm_map(const char *uri, size_t size, bool write, tp_shm_mapping_t *mapping)
{
    if ((uri == NULL) || (mapping == NULL) || (size == 0))
    {
        return TP_ERR_ARG;
    }
    char path_buf[TP_URI_MAX];
    bool require_hugepages = false;
    tp_err_t parse_err = tp_parse_shm_uri(uri, path_buf, sizeof(path_buf), &require_hugepages);
    if (parse_err != TP_OK)
    {
        return parse_err;
    }
    if (require_hugepages)
    {
        return TP_ERR_UNSUPPORTED;
    }

    struct stat st_path;
    if (lstat(path_buf, &st_path) != 0)
    {
        return TP_ERR_IO;
    }
    if (S_ISLNK(st_path.st_mode))
    {
        return TP_ERR_PROTOCOL;
    }

    int flags = write ? O_RDWR : O_RDONLY;
#ifdef O_NOFOLLOW
    flags |= O_NOFOLLOW;
#endif
    int fd = open(path_buf, flags);
    if (fd < 0)
    {
        return TP_ERR_IO;
    }

    struct stat st_fd;
    if (fstat(fd, &st_fd) != 0)
    {
        close(fd);
        return TP_ERR_IO;
    }
    if (!S_ISREG(st_fd.st_mode))
    {
        close(fd);
        return TP_ERR_PROTOCOL;
    }

    if ((st_fd.st_ino != st_path.st_ino) || (st_fd.st_dev != st_path.st_dev))
    {
        close(fd);
        return TP_ERR_PROTOCOL;
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
    if ((mapping == NULL) || (mapping->addr == NULL) || (mapping->length == 0))
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
    if ((mapping == NULL) || (mapping->addr == NULL) || (mapping->length < TP_SUPERBLOCK_SIZE))
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
    enum shm_tensorpool_control_regionType region_val;
    if (!shm_tensorpool_control_shmRegionSuperblock_regionType(&sb, &region_val))
    {
        return TP_ERR_PROTOCOL;
    }
    if ((uint16_t)region_val != expected_region_type)
    {
        return TP_ERR_PROTOCOL;
    }
    return TP_OK;
}
