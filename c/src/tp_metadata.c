#include "tp_internal.h"
#include <stdio.h>

static void tp_copy_ascii(char *dst, size_t dst_len, const char *src, uint32_t len)
{
    if (dst_len == 0)
    {
        return;
    }
    uint32_t to_copy = len < (dst_len - 1) ? len : (uint32_t)(dst_len - 1);
    if (to_copy > 0 && src != NULL)
    {
        memcpy(dst, src, to_copy);
    }
    dst[to_copy] = '\0';
}

static tp_metadata_entry_t *tp_find_metadata_entry(tp_metadata_cache_t *cache, uint32_t stream_id)
{
    for (uint32_t i = 0; i < cache->entry_count; i++)
    {
        if (cache->entries[i].stream_id == stream_id)
        {
            return &cache->entries[i];
        }
    }
    return NULL;
}

static const tp_metadata_entry_t *tp_find_metadata_entry_const(const tp_metadata_cache_t *cache, uint32_t stream_id)
{
    for (uint32_t i = 0; i < cache->entry_count; i++)
    {
        if (cache->entries[i].stream_id == stream_id)
        {
            return &cache->entries[i];
        }
    }
    return NULL;
}

static tp_metadata_entry_t *tp_get_metadata_entry(tp_metadata_cache_t *cache, uint32_t stream_id)
{
    tp_metadata_entry_t *entry = tp_find_metadata_entry(cache, stream_id);
    if (entry != NULL)
    {
        return entry;
    }
    if (cache->entry_count >= TP_MAX_METADATA_ENTRIES)
    {
        return NULL;
    }
    entry = &cache->entries[cache->entry_count++];
    memset(entry, 0, sizeof(*entry));
    entry->stream_id = stream_id;
    return entry;
}

static void tp_handle_metadata_announce(tp_metadata_cache_t *cache, char *buffer, size_t length, struct shm_tensorpool_control_messageHeader *hdr)
{
    struct shm_tensorpool_control_dataSourceAnnounce msg;
    const uint64_t acting_block_length = shm_tensorpool_control_messageHeader_blockLength(hdr);
    const uint64_t acting_version = shm_tensorpool_control_messageHeader_version(hdr);
    shm_tensorpool_control_dataSourceAnnounce_wrap_for_decode(
        &msg,
        buffer + shm_tensorpool_control_messageHeader_encoded_length(),
        0,
        acting_block_length,
        acting_version,
        length - shm_tensorpool_control_messageHeader_encoded_length());

    uint32_t stream_id = shm_tensorpool_control_dataSourceAnnounce_streamId(&msg);
    tp_metadata_entry_t *entry = tp_get_metadata_entry(cache, stream_id);
    if (entry == NULL)
    {
        return;
    }

    entry->producer_id = shm_tensorpool_control_dataSourceAnnounce_producerId(&msg);
    entry->epoch = shm_tensorpool_control_dataSourceAnnounce_epoch(&msg);
    entry->meta_version = shm_tensorpool_control_dataSourceAnnounce_metaVersion(&msg);

    struct shm_tensorpool_control_dataSourceAnnounce_string_view name_view =
        shm_tensorpool_control_dataSourceAnnounce_get_name_as_string_view(&msg);
    tp_copy_ascii(entry->name, sizeof(entry->name), name_view.data, (uint32_t)name_view.length);

    struct shm_tensorpool_control_dataSourceAnnounce_string_view summary_view =
        shm_tensorpool_control_dataSourceAnnounce_get_summary_as_string_view(&msg);
    tp_copy_ascii(entry->summary, sizeof(entry->summary), summary_view.data, (uint32_t)summary_view.length);
}

static void tp_handle_metadata_meta(tp_metadata_cache_t *cache, char *buffer, size_t length, struct shm_tensorpool_control_messageHeader *hdr)
{
    struct shm_tensorpool_control_dataSourceMeta msg;
    const uint64_t acting_block_length = shm_tensorpool_control_messageHeader_blockLength(hdr);
    const uint64_t acting_version = shm_tensorpool_control_messageHeader_version(hdr);
    shm_tensorpool_control_dataSourceMeta_wrap_for_decode(
        &msg,
        buffer + shm_tensorpool_control_messageHeader_encoded_length(),
        0,
        acting_block_length,
        acting_version,
        length - shm_tensorpool_control_messageHeader_encoded_length());

    uint32_t stream_id = shm_tensorpool_control_dataSourceMeta_streamId(&msg);
    tp_metadata_entry_t *entry = tp_get_metadata_entry(cache, stream_id);
    if (entry == NULL)
    {
        return;
    }

    entry->meta_version = shm_tensorpool_control_dataSourceMeta_metaVersion(&msg);
    entry->timestamp_ns = shm_tensorpool_control_dataSourceMeta_timestampNs(&msg);
    entry->attr_count = 0;

    struct shm_tensorpool_control_dataSourceMeta_attributes attrs;
    if (!shm_tensorpool_control_dataSourceMeta_attributes_wrap_for_decode(
            &attrs,
            msg.buffer,
            shm_tensorpool_control_dataSourceMeta_sbe_position_ptr(&msg),
            acting_version,
            msg.buffer_length))
    {
        return;
    }

    while (shm_tensorpool_control_dataSourceMeta_attributes_has_next(&attrs) &&
        entry->attr_count < TP_MAX_METADATA_ATTRS)
    {
        shm_tensorpool_control_dataSourceMeta_attributes_next(&attrs);
        tp_metadata_attribute_t *dest = &entry->attrs[entry->attr_count++];

        struct shm_tensorpool_control_dataSourceMeta_string_view key_view =
            shm_tensorpool_control_dataSourceMeta_attributes_get_key_as_string_view(&attrs);
        tp_copy_ascii(dest->key, sizeof(dest->key), key_view.data, (uint32_t)key_view.length);

        struct shm_tensorpool_control_dataSourceMeta_string_view mime_view =
            shm_tensorpool_control_dataSourceMeta_attributes_get_format_as_string_view(&attrs);
        tp_copy_ascii(dest->mime_type, sizeof(dest->mime_type), mime_view.data, (uint32_t)mime_view.length);

        uint32_t value_len = shm_tensorpool_control_dataSourceMeta_attributes_value_length(&attrs);
        if (value_len > TP_METADATA_VALUE_MAX)
        {
            value_len = TP_METADATA_VALUE_MAX;
        }
        dest->value_len = value_len;
        if (value_len > 0)
        {
            const uint8_t *value_ptr = (const uint8_t *)shm_tensorpool_control_dataSourceMeta_attributes_value(&attrs);
            memcpy(dest->value, value_ptr, value_len);
        }
    }
}

static void tp_metadata_handle_buffer(tp_metadata_cache_t *cache, const uint8_t *buffer, size_t length)
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
    if (schema_id != shm_tensorpool_control_dataSourceAnnounce_sbe_schema_id())
    {
        return;
    }
    uint16_t template_id = shm_tensorpool_control_messageHeader_templateId(&hdr);
    if (template_id == shm_tensorpool_control_dataSourceAnnounce_sbe_template_id())
    {
        tp_handle_metadata_announce(cache, buf, length, &hdr);
    }
    else if (template_id == shm_tensorpool_control_dataSourceMeta_sbe_template_id())
    {
        tp_handle_metadata_meta(cache, buf, length, &hdr);
    }
}

static void tp_metadata_fragment_handler(void *clientd, const uint8_t *buffer, size_t length, aeron_header_t *header)
{
    (void)header;
    tp_metadata_cache_t *cache = (tp_metadata_cache_t *)clientd;
    tp_metadata_handle_buffer(cache, buffer, length);
}

void tp_metadata_cache_handle_buffer(tp_metadata_cache_t *cache, char *buffer, size_t length)
{
    if ((cache == NULL) || (buffer == NULL))
    {
        return;
    }
    tp_metadata_handle_buffer(cache, (const uint8_t *)buffer, length);
}

tp_err_t tp_metadata_cache_init(tp_client_t *client, const char *channel, int32_t stream_id, tp_metadata_cache_t **cache)
{
    if ((client == NULL) || (channel == NULL) || (cache == NULL))
    {
        return TP_ERR_ARG;
    }
    tp_metadata_cache_t *state = (tp_metadata_cache_t *)calloc(1, sizeof(tp_metadata_cache_t));
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
    if (aeron_fragment_assembler_create(&state->assembler, tp_metadata_fragment_handler, state) < 0)
    {
        aeron_subscription_close(state->sub, NULL, NULL);
        free(state);
        return TP_ERR_AERON;
    }
    *cache = state;
    return TP_OK;
}

void tp_metadata_cache_close(tp_metadata_cache_t *cache)
{
    if (cache == NULL)
    {
        return;
    }
    if (cache->assembler)
    {
        aeron_fragment_assembler_delete(cache->assembler);
    }
    if (cache->sub)
    {
        aeron_subscription_close(cache->sub, NULL, NULL);
    }
    free(cache);
}

int tp_metadata_cache_poll(tp_metadata_cache_t *cache, int fragment_limit)
{
    if (cache == NULL)
    {
        return 0;
    }
    return aeron_subscription_poll(
        cache->sub,
        aeron_fragment_assembler_handler,
        cache->assembler,
        (size_t)fragment_limit);
}

tp_err_t tp_metadata_cache_get(const tp_metadata_cache_t *cache, uint32_t stream_id, tp_metadata_entry_t *out)
{
    if ((cache == NULL) || (out == NULL))
    {
        return TP_ERR_ARG;
    }
    const tp_metadata_entry_t *entry = tp_find_metadata_entry_const(cache, stream_id);
    if (entry == NULL)
    {
        return TP_ERR_NOT_FOUND;
    }
    *out = *entry;
    return TP_OK;
}
