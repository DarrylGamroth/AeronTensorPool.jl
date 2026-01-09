#include <assert.h>
#include <string.h>

#include "tp_internal.h"

static size_t tp_metadata_announce_length(const struct shm_tensorpool_control_dataSourceAnnounce *msg)
{
    return shm_tensorpool_control_messageHeader_encoded_length() +
        shm_tensorpool_control_dataSourceAnnounce_encoded_length(msg);
}

static size_t tp_metadata_meta_length(const struct shm_tensorpool_control_dataSourceMeta *msg)
{
    return shm_tensorpool_control_messageHeader_encoded_length() +
        shm_tensorpool_control_dataSourceMeta_encoded_length(msg);
}

int main(void)
{
    tp_metadata_cache_t cache;
    memset(&cache, 0, sizeof(cache));

    char buffer[1024];
    memset(buffer, 0, sizeof(buffer));

    struct shm_tensorpool_control_dataSourceAnnounce ann;
    struct shm_tensorpool_control_messageHeader header;
    shm_tensorpool_control_dataSourceAnnounce_wrap_and_apply_header(&ann, buffer, 0, sizeof(buffer), &header);
    shm_tensorpool_control_dataSourceAnnounce_set_streamId(&ann, 10000);
    shm_tensorpool_control_dataSourceAnnounce_set_producerId(&ann, 11);
    shm_tensorpool_control_dataSourceAnnounce_set_epoch(&ann, 3);
    shm_tensorpool_control_dataSourceAnnounce_set_metaVersion(&ann, 5);
    shm_tensorpool_control_dataSourceAnnounce_put_name(&ann, "sourceA", 7);
    shm_tensorpool_control_dataSourceAnnounce_put_summary(&ann, "summary", 7);

    tp_metadata_cache_handle_buffer(&cache, buffer, tp_metadata_announce_length(&ann));

    assert(cache.entry_count == 1);
    assert(cache.entries[0].stream_id == 10000);
    assert(cache.entries[0].producer_id == 11);
    assert(cache.entries[0].epoch == 3);
    assert(cache.entries[0].meta_version == 5);
    assert(strcmp(cache.entries[0].name, "sourceA") == 0);
    assert(strcmp(cache.entries[0].summary, "summary") == 0);

    memset(buffer, 0, sizeof(buffer));
    struct shm_tensorpool_control_dataSourceMeta meta;
    shm_tensorpool_control_dataSourceMeta_wrap_and_apply_header(&meta, buffer, 0, sizeof(buffer), &header);
    shm_tensorpool_control_dataSourceMeta_set_streamId(&meta, 10000);
    shm_tensorpool_control_dataSourceMeta_set_metaVersion(&meta, 6);
    shm_tensorpool_control_dataSourceMeta_set_timestampNs(&meta, 123456);

    struct shm_tensorpool_control_dataSourceMeta_attributes attrs;
    shm_tensorpool_control_dataSourceMeta_attributes_set_count(&meta, &attrs, 1);
    shm_tensorpool_control_dataSourceMeta_attributes_next(&attrs);
    shm_tensorpool_control_dataSourceMeta_attributes_put_key(&attrs, "k1", 2);
    shm_tensorpool_control_dataSourceMeta_attributes_put_format(&attrs, "text/plain", 10);
    shm_tensorpool_control_dataSourceMeta_attributes_put_value(&attrs, (const char *)"abc", 3);

    tp_metadata_cache_handle_buffer(&cache, buffer, tp_metadata_meta_length(&meta));

    assert(cache.entry_count == 1);
    assert(cache.entries[0].meta_version == 6);
    assert(cache.entries[0].timestamp_ns == 123456);
    assert(cache.entries[0].attr_count == 1);
    assert(strcmp(cache.entries[0].attrs[0].key, "k1") == 0);
    assert(strcmp(cache.entries[0].attrs[0].mime_type, "text/plain") == 0);
    assert(cache.entries[0].attrs[0].value_len == 3);
    assert(memcmp(cache.entries[0].attrs[0].value, "abc", 3) == 0);

    return 0;
}
