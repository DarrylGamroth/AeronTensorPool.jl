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

static void tp_handle_discovery_response(tp_discovery_client_t *client, char *buffer, size_t length, struct shm_tensorpool_discovery_messageHeader *hdr)
{
    struct shm_tensorpool_discovery_discoveryResponse msg;
    const uint64_t acting_block_length = shm_tensorpool_discovery_messageHeader_blockLength(hdr);
    const uint64_t acting_version = shm_tensorpool_discovery_messageHeader_version(hdr);
    shm_tensorpool_discovery_discoveryResponse_wrap_for_decode(
        &msg,
        buffer + shm_tensorpool_discovery_messageHeader_encoded_length(),
        0,
        acting_block_length,
        acting_version,
        length - shm_tensorpool_discovery_messageHeader_encoded_length());

    uint64_t request_id = shm_tensorpool_discovery_discoveryResponse_requestId(&msg);
    client->last_request_id = request_id;
    enum shm_tensorpool_discovery_discoveryStatus status;
    if (!shm_tensorpool_discovery_discoveryResponse_status(&msg, &status))
    {
        status = shm_tensorpool_discovery_discoveryStatus_NULL_VALUE;
    }
    client->last_status = (int32_t)status;
    client->entry_count = 0;
    client->last_error[0] = '\0';

    if (client->last_status != shm_tensorpool_discovery_discoveryStatus_OK)
    {
        struct shm_tensorpool_discovery_discoveryResponse_string_view err_view =
            shm_tensorpool_discovery_discoveryResponse_get_errorMessage_as_string_view(&msg);
        tp_copy_ascii(client->last_error, sizeof(client->last_error), err_view.data, (uint32_t)err_view.length);
        return;
    }

    struct shm_tensorpool_discovery_discoveryResponse_results results;
    if (!shm_tensorpool_discovery_discoveryResponse_results_wrap_for_decode(
            &results,
            msg.buffer,
            shm_tensorpool_discovery_discoveryResponse_sbe_position_ptr(&msg),
            acting_version,
            msg.buffer_length))
    {
        return;
    }

    while (shm_tensorpool_discovery_discoveryResponse_results_has_next(&results) &&
        client->entry_count < TP_MAX_DISCOVERY_ENTRIES)
    {
        shm_tensorpool_discovery_discoveryResponse_results_next(&results);
        tp_discovery_entry_t *entry = &client->entries[client->entry_count++];
        memset(entry, 0, sizeof(*entry));

        entry->stream_id = shm_tensorpool_discovery_discoveryResponse_results_streamId(&results);
        entry->producer_id = shm_tensorpool_discovery_discoveryResponse_results_producerId(&results);
        entry->epoch = shm_tensorpool_discovery_discoveryResponse_results_epoch(&results);
        entry->layout_version = shm_tensorpool_discovery_discoveryResponse_results_layoutVersion(&results);
        entry->header_nslots = shm_tensorpool_discovery_discoveryResponse_results_headerNslots(&results);
        entry->header_slot_bytes = shm_tensorpool_discovery_discoveryResponse_results_headerSlotBytes(&results);
        entry->max_dims = shm_tensorpool_discovery_discoveryResponse_results_maxDims(&results);
        entry->data_source_id = (uint32_t)shm_tensorpool_discovery_discoveryResponse_results_dataSourceId(&results);
        entry->driver_control_stream_id = shm_tensorpool_discovery_discoveryResponse_results_driverControlStreamId(&results);

        struct shm_tensorpool_discovery_discoveryResponse_string_view header_view =
            shm_tensorpool_discovery_discoveryResponse_results_get_headerRegionUri_as_string_view(&results);
        tp_copy_ascii(entry->header_region_uri, sizeof(entry->header_region_uri), header_view.data, (uint32_t)header_view.length);

        struct shm_tensorpool_discovery_discoveryResponse_string_view data_name_view =
            shm_tensorpool_discovery_discoveryResponse_results_get_dataSourceName_as_string_view(&results);
        tp_copy_ascii(entry->data_source_name, sizeof(entry->data_source_name), data_name_view.data, (uint32_t)data_name_view.length);

        struct shm_tensorpool_discovery_discoveryResponse_string_view driver_id_view =
            shm_tensorpool_discovery_discoveryResponse_results_get_driverInstanceId_as_string_view(&results);
        tp_copy_ascii(entry->driver_instance_id, sizeof(entry->driver_instance_id), driver_id_view.data, (uint32_t)driver_id_view.length);

        struct shm_tensorpool_discovery_discoveryResponse_string_view driver_channel_view =
            shm_tensorpool_discovery_discoveryResponse_results_get_driverControlChannel_as_string_view(&results);
        tp_copy_ascii(entry->driver_control_channel, sizeof(entry->driver_control_channel), driver_channel_view.data, (uint32_t)driver_channel_view.length);

        entry->pool_count = 0;
        struct shm_tensorpool_discovery_discoveryResponse_results_payloadPools pools;
        if (shm_tensorpool_discovery_discoveryResponse_results_payloadPools_wrap_for_decode(
                &pools,
                results.buffer,
                shm_tensorpool_discovery_discoveryResponse_results_sbe_position_ptr(&results),
                acting_version,
                results.buffer_length))
        {
            while (shm_tensorpool_discovery_discoveryResponse_results_payloadPools_has_next(&pools) &&
                entry->pool_count < TP_MAX_POOLS)
            {
                shm_tensorpool_discovery_discoveryResponse_results_payloadPools_next(&pools);
                tp_discovery_pool_entry_t *pool = &entry->pools[entry->pool_count++];
                pool->pool_id = shm_tensorpool_discovery_discoveryResponse_results_payloadPools_poolId(&pools);
                pool->pool_nslots = shm_tensorpool_discovery_discoveryResponse_results_payloadPools_poolNslots(&pools);
                pool->stride_bytes = shm_tensorpool_discovery_discoveryResponse_results_payloadPools_strideBytes(&pools);
                struct shm_tensorpool_discovery_discoveryResponse_string_view uri_view =
                    shm_tensorpool_discovery_discoveryResponse_results_payloadPools_get_regionUri_as_string_view(&pools);
                tp_copy_ascii(pool->region_uri, sizeof(pool->region_uri), uri_view.data, (uint32_t)uri_view.length);
            }
        }

        entry->tag_count = 0;
        struct shm_tensorpool_discovery_discoveryResponse_results_tags tags;
        if (shm_tensorpool_discovery_discoveryResponse_results_tags_wrap_for_decode(
                &tags,
                results.buffer,
                shm_tensorpool_discovery_discoveryResponse_results_sbe_position_ptr(&results),
                acting_version,
                results.buffer_length))
        {
            while (shm_tensorpool_discovery_discoveryResponse_results_tags_has_next(&tags) &&
                entry->tag_count < TP_MAX_TAGS)
            {
                shm_tensorpool_discovery_discoveryResponse_results_tags_next(&tags);
                struct shm_tensorpool_discovery_varAsciiEncoding tag_var;
                if (NULL == shm_tensorpool_discovery_discoveryResponse_results_tags_tag(&tags, &tag_var))
                {
                    continue;
                }
                uint32_t tag_len = shm_tensorpool_discovery_varAsciiEncoding_length(&tag_var);
                const char *tag_ptr =
                    shm_tensorpool_discovery_varAsciiEncoding_buffer(&tag_var) +
                    shm_tensorpool_discovery_varAsciiEncoding_offset(&tag_var) +
                    shm_tensorpool_discovery_varAsciiEncoding_varData_encoding_offset();
                tp_copy_ascii(entry->tags[entry->tag_count], sizeof(entry->tags[entry->tag_count]), tag_ptr, tag_len);
                entry->tag_count++;
            }
        }
    }
}

static void tp_discovery_handle_buffer(tp_discovery_client_t *client, const uint8_t *buffer, size_t length)
{
    if (length < shm_tensorpool_discovery_messageHeader_encoded_length())
    {
        return;
    }
    char *buf = (char *)buffer;
    struct shm_tensorpool_discovery_messageHeader hdr;
    if (!shm_tensorpool_discovery_messageHeader_wrap(
            &hdr, buf, 0, shm_tensorpool_discovery_messageHeader_sbe_schema_version(), length))
    {
        return;
    }
    if (shm_tensorpool_discovery_messageHeader_version(&hdr) > shm_tensorpool_discovery_messageHeader_sbe_schema_version())
    {
        return;
    }
    uint16_t schema_id = shm_tensorpool_discovery_messageHeader_schemaId(&hdr);
    if (schema_id != shm_tensorpool_discovery_discoveryResponse_sbe_schema_id())
    {
        return;
    }
    if (shm_tensorpool_discovery_messageHeader_templateId(&hdr) != shm_tensorpool_discovery_discoveryResponse_sbe_template_id())
    {
        return;
    }
    tp_handle_discovery_response(client, buf, length, &hdr);
}

static void tp_discovery_fragment_handler(void *clientd, const uint8_t *buffer, size_t length, aeron_header_t *header)
{
    (void)header;
    tp_discovery_client_t *client = (tp_discovery_client_t *)clientd;
    tp_discovery_handle_buffer(client, buffer, length);
}

void tp_discovery_client_handle_buffer(tp_discovery_client_t *client, char *buffer, size_t length)
{
    if (client == NULL || buffer == NULL)
    {
        return;
    }
    tp_discovery_handle_buffer(client, (const uint8_t *)buffer, length);
}

tp_err_t tp_discovery_client_init(
    tp_client_t *client,
    const char *request_channel,
    int32_t request_stream_id,
    const char *response_channel,
    int32_t response_stream_id,
    tp_discovery_client_t **discovery)
{
    if (client == NULL || request_channel == NULL || response_channel == NULL || discovery == NULL)
    {
        return TP_ERR_ARG;
    }
    tp_discovery_client_t *state = (tp_discovery_client_t *)calloc(1, sizeof(tp_discovery_client_t));
    if (state == NULL)
    {
        return TP_ERR_NOMEM;
    }
    state->client = client;
    state->next_request_id = 1;

    if (tp_add_publication(client->aeron, request_channel, request_stream_id, &state->pub) < 0)
    {
        free(state);
        return TP_ERR_AERON;
    }
    if (tp_add_subscription(client->aeron, response_channel, response_stream_id, &state->sub) < 0)
    {
        aeron_publication_close(state->pub, NULL, NULL);
        free(state);
        return TP_ERR_AERON;
    }
    if (aeron_fragment_assembler_create(&state->assembler, tp_discovery_fragment_handler, state) < 0)
    {
        aeron_subscription_close(state->sub, NULL, NULL);
        aeron_publication_close(state->pub, NULL, NULL);
        free(state);
        return TP_ERR_AERON;
    }
    snprintf(state->response_channel, sizeof(state->response_channel), "%s", response_channel);
    state->response_stream_id = response_stream_id;
    *discovery = state;
    return TP_OK;
}

void tp_discovery_client_close(tp_discovery_client_t *discovery)
{
    if (discovery == NULL)
    {
        return;
    }
    if (discovery->assembler)
    {
        aeron_fragment_assembler_delete(discovery->assembler);
    }
    if (discovery->sub)
    {
        aeron_subscription_close(discovery->sub, NULL, NULL);
    }
    if (discovery->pub)
    {
        aeron_publication_close(discovery->pub, NULL, NULL);
    }
    free(discovery);
}

int tp_discovery_client_poll(tp_discovery_client_t *discovery, int fragment_limit)
{
    if (discovery == NULL)
    {
        return 0;
    }
    return aeron_subscription_poll(
        discovery->sub,
        aeron_fragment_assembler_handler,
        discovery->assembler,
        (size_t)fragment_limit);
}

tp_err_t tp_discovery_send_request(
    tp_discovery_client_t *discovery,
    uint32_t stream_id,
    uint32_t producer_id,
    uint32_t data_source_id,
    const char *data_source_name,
    const char **tags,
    uint32_t tag_count,
    uint64_t *request_id)
{
    if (discovery == NULL || request_id == NULL)
    {
        return TP_ERR_ARG;
    }

    aeron_buffer_claim_t claim;
    size_t name_len = data_source_name ? strlen(data_source_name) : 0;
    size_t tags_len = 0;
    for (uint32_t i = 0; i < tag_count; i++)
    {
        if (tags[i] != NULL)
        {
            tags_len += strlen(tags[i]);
        }
    }

    const uint64_t msg_len =
        shm_tensorpool_discovery_messageHeader_encoded_length() +
        shm_tensorpool_discovery_discoveryRequest_sbe_block_length() +
        shm_tensorpool_discovery_discoveryRequest_tags_sbe_header_size() +
        tag_count * shm_tensorpool_discovery_discoveryRequest_tags_sbe_block_length() +
        shm_tensorpool_discovery_discoveryRequest_responseChannel_header_length() +
        shm_tensorpool_discovery_discoveryRequest_dataSourceName_header_length() +
        name_len + tags_len;

    const int64_t position = aeron_publication_try_claim(discovery->pub, msg_len, &claim);
    if (position < 0)
    {
        return TP_ERR_AERON;
    }

    struct shm_tensorpool_discovery_messageHeader hdr;
    struct shm_tensorpool_discovery_discoveryRequest msg;
    shm_tensorpool_discovery_discoveryRequest_wrap_and_apply_header(
        &msg,
        (char *)claim.data,
        0,
        msg_len,
        &hdr);

    uint64_t req_id = discovery->next_request_id++;
    shm_tensorpool_discovery_discoveryRequest_set_requestId(&msg, req_id);
    shm_tensorpool_discovery_discoveryRequest_set_clientId(&msg, discovery->client->context->client_id);
    shm_tensorpool_discovery_discoveryRequest_set_responseStreamId(&msg, (uint32_t)discovery->response_stream_id);

    uint32_t stream_val = stream_id == 0 ? shm_tensorpool_discovery_discoveryRequest_streamId_null_value() : stream_id;
    uint32_t producer_val = producer_id == 0 ? shm_tensorpool_discovery_discoveryRequest_producerId_null_value() : producer_id;
    uint64_t data_val = data_source_id == 0 ? shm_tensorpool_discovery_discoveryRequest_dataSourceId_null_value() : data_source_id;
    shm_tensorpool_discovery_discoveryRequest_set_streamId(&msg, stream_val);
    shm_tensorpool_discovery_discoveryRequest_set_producerId(&msg, producer_val);
    shm_tensorpool_discovery_discoveryRequest_set_dataSourceId(&msg, data_val);

    struct shm_tensorpool_discovery_discoveryRequest_tags tags_group;
    shm_tensorpool_discovery_discoveryRequest_tags_set_count(&msg, &tags_group, (uint16_t)tag_count);
    for (uint32_t i = 0; i < tag_count; i++)
    {
        shm_tensorpool_discovery_discoveryRequest_tags_next(&tags_group);
        const char *tag = tags[i] != NULL ? tags[i] : "";
        struct shm_tensorpool_discovery_varAsciiEncoding tag_var;
        if (NULL == shm_tensorpool_discovery_discoveryRequest_tags_tag(&tags_group, &tag_var))
        {
            continue;
        }
        size_t tag_len = strlen(tag);
        if (tag_len > UINT32_MAX)
        {
            tag_len = UINT32_MAX;
        }
        shm_tensorpool_discovery_varAsciiEncoding_set_length(&tag_var, (uint32_t)tag_len);
        memcpy(
            shm_tensorpool_discovery_varAsciiEncoding_mut_buffer(&tag_var) +
                shm_tensorpool_discovery_varAsciiEncoding_offset(&tag_var) +
                shm_tensorpool_discovery_varAsciiEncoding_varData_encoding_offset(),
            tag,
            tag_len);
    }

    shm_tensorpool_discovery_discoveryRequest_put_responseChannel(
        &msg,
        discovery->response_channel,
        strlen(discovery->response_channel));
    if (data_source_name != NULL)
    {
        shm_tensorpool_discovery_discoveryRequest_put_dataSourceName(&msg, data_source_name, strlen(data_source_name));
    }
    else
    {
        shm_tensorpool_discovery_discoveryRequest_put_dataSourceName(&msg, "", 0);
    }

    aeron_buffer_claim_commit(&claim);
    *request_id = req_id;
    return TP_OK;
}

tp_err_t tp_discovery_get_response(
    const tp_discovery_client_t *discovery,
    uint64_t request_id,
    tp_discovery_entry_t *entries,
    uint32_t *entry_count,
    char *error_message,
    size_t error_len,
    int32_t *status)
{
    if (discovery == NULL || entries == NULL || entry_count == NULL || status == NULL)
    {
        return TP_ERR_ARG;
    }
    if (discovery->last_request_id != request_id)
    {
        return TP_ERR_TIMEOUT;
    }
    *status = discovery->last_status;
    if (error_message != NULL && error_len > 0)
    {
        tp_copy_ascii(error_message, error_len, discovery->last_error, (uint32_t)strlen(discovery->last_error));
    }
    uint32_t count = discovery->entry_count;
    for (uint32_t i = 0; i < count; i++)
    {
        entries[i] = discovery->entries[i];
    }
    *entry_count = count;
    return TP_OK;
}
