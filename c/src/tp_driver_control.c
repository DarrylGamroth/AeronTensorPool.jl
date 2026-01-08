#include "tp_internal.h"

int tp_add_publication(aeron_t *client, const char *channel, int32_t stream_id, aeron_publication_t **pub)
{
    aeron_async_add_publication_t *async = NULL;
    if (aeron_async_add_publication(&async, client, channel, stream_id) < 0)
    {
        return -1;
    }
    while (aeron_async_add_publication_poll(pub, async) == 0)
    {
        aeron_main_do_work(client);
    }
    return *pub != NULL ? 0 : -1;
}

int tp_add_subscription(aeron_t *client, const char *channel, int32_t stream_id, aeron_subscription_t **sub)
{
    aeron_async_add_subscription_t *async = NULL;
    if (aeron_async_add_subscription(&async, client, channel, stream_id, NULL, NULL, NULL, NULL) < 0)
    {
        return -1;
    }
    while (aeron_async_add_subscription_poll(sub, async) == 0)
    {
        aeron_main_do_work(client);
    }
    return *sub != NULL ? 0 : -1;
}

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

static void tp_decode_attach_response(tp_driver_client_t *driver, char *buffer, size_t length)
{
    struct shm_tensorpool_driver_messageHeader hdr;
    if (!shm_tensorpool_driver_messageHeader_wrap(
            &hdr, buffer, 0, shm_tensorpool_driver_messageHeader_sbe_schema_version(), length))
    {
        return;
    }

    const uint16_t template_id = shm_tensorpool_driver_messageHeader_templateId(&hdr);
    if (template_id != shm_tensorpool_driver_shmAttachResponse_sbe_template_id())
    {
        return;
    }

    struct shm_tensorpool_driver_shmAttachResponse resp;
    const uint64_t acting_block_length = shm_tensorpool_driver_messageHeader_blockLength(&hdr);
    const uint64_t acting_version = shm_tensorpool_driver_messageHeader_version(&hdr);
    shm_tensorpool_driver_shmAttachResponse_wrap_for_decode(
        &resp,
        buffer + shm_tensorpool_driver_messageHeader_encoded_length(),
        0,
        acting_block_length,
        acting_version,
        length - shm_tensorpool_driver_messageHeader_encoded_length());

    tp_attach_response_t *out = &driver->last_attach;
    memset(out, 0, sizeof(*out));
    out->correlation_id = shm_tensorpool_driver_shmAttachResponse_correlationId(&resp);
    out->code = shm_tensorpool_driver_shmAttachResponse_code(&resp);
    out->lease_id = shm_tensorpool_driver_shmAttachResponse_leaseId(&resp);
    out->lease_expiry_ns = shm_tensorpool_driver_shmAttachResponse_leaseExpiryTimestampNs(&resp);
    out->stream_id = shm_tensorpool_driver_shmAttachResponse_streamId(&resp);
    out->epoch = shm_tensorpool_driver_shmAttachResponse_epoch(&resp);
    out->layout_version = shm_tensorpool_driver_shmAttachResponse_layoutVersion(&resp);
    out->header_nslots = shm_tensorpool_driver_shmAttachResponse_headerNslots(&resp);
    out->header_slot_bytes = shm_tensorpool_driver_shmAttachResponse_headerSlotBytes(&resp);
    out->max_dims = shm_tensorpool_driver_shmAttachResponse_maxDims(&resp);

    struct shm_tensorpool_driver_shmAttachResponse_payloadPools pools;
    uint64_t pos = shm_tensorpool_driver_shmAttachResponse_sbe_position(&resp);
    if (shm_tensorpool_driver_shmAttachResponse_payloadPools_wrap_for_decode(&pools, resp.buffer, &pos, acting_version, resp.buffer_length))
    {
        uint32_t count = (uint32_t)shm_tensorpool_driver_shmAttachResponse_payloadPools_count(&pools);
        if (count > TP_MAX_POOLS)
        {
            count = TP_MAX_POOLS;
        }
        out->pool_count = count;
        for (uint32_t i = 0; i < count && shm_tensorpool_driver_shmAttachResponse_payloadPools_has_next(&pools); i++)
        {
            shm_tensorpool_driver_shmAttachResponse_payloadPools_next(&pools);
            out->pools[i].pool_id = shm_tensorpool_driver_shmAttachResponse_payloadPools_poolId(&pools);
            out->pools[i].nslots = shm_tensorpool_driver_shmAttachResponse_payloadPools_poolNslots(&pools);
            out->pools[i].stride_bytes = shm_tensorpool_driver_shmAttachResponse_payloadPools_strideBytes(&pools);
            uint32_t uri_len = shm_tensorpool_driver_shmAttachResponse_payloadPools_regionUri_length(&pools);
            const char *uri = shm_tensorpool_driver_shmAttachResponse_payloadPools_regionUri(&pools);
            tp_copy_ascii(out->pools[i].uri, sizeof(out->pools[i].uri), uri, uri_len);
        }
    }

    uint32_t header_len = shm_tensorpool_driver_shmAttachResponse_headerRegionUri_length(&resp);
    const char *header_uri = shm_tensorpool_driver_shmAttachResponse_headerRegionUri(&resp);
    tp_copy_ascii(out->header_uri, sizeof(out->header_uri), header_uri, header_len);

    uint32_t err_len = shm_tensorpool_driver_shmAttachResponse_errorMessage_length(&resp);
    const char *err_msg = shm_tensorpool_driver_shmAttachResponse_errorMessage(&resp);
    tp_copy_ascii(out->error_message, sizeof(out->error_message), err_msg, err_len);

    driver->last_attach_correlation = out->correlation_id;
}

static void tp_decode_detach_response(tp_driver_client_t *driver, char *buffer, size_t length)
{
    struct shm_tensorpool_driver_messageHeader hdr;
    if (!shm_tensorpool_driver_messageHeader_wrap(
            &hdr, buffer, 0, shm_tensorpool_driver_messageHeader_sbe_schema_version(), length))
    {
        return;
    }
    if (shm_tensorpool_driver_messageHeader_templateId(&hdr) != shm_tensorpool_driver_shmDetachResponse_sbe_template_id())
    {
        return;
    }
    struct shm_tensorpool_driver_shmDetachResponse resp;
    const uint64_t acting_block_length = shm_tensorpool_driver_messageHeader_blockLength(&hdr);
    const uint64_t acting_version = shm_tensorpool_driver_messageHeader_version(&hdr);
    shm_tensorpool_driver_shmDetachResponse_wrap_for_decode(
        &resp,
        buffer + shm_tensorpool_driver_messageHeader_encoded_length(),
        0,
        acting_block_length,
        acting_version,
        length - shm_tensorpool_driver_messageHeader_encoded_length());

    driver->last_detach_correlation = shm_tensorpool_driver_shmDetachResponse_correlationId(&resp);
    driver->last_detach_code = shm_tensorpool_driver_shmDetachResponse_code(&resp);
}

static void tp_driver_fragment_handler(void *clientd, const uint8_t *buffer, size_t length, aeron_header_t *header)
{
    (void)header;
    tp_driver_client_t *driver = (tp_driver_client_t *)clientd;
    if (length < shm_tensorpool_driver_messageHeader_encoded_length())
    {
        return;
    }
    char *buf = (char *)buffer;
    struct shm_tensorpool_driver_messageHeader hdr;
    if (!shm_tensorpool_driver_messageHeader_wrap(
            &hdr, buf, 0, shm_tensorpool_driver_messageHeader_sbe_schema_version(), length))
    {
        return;
    }
    uint16_t template_id = shm_tensorpool_driver_messageHeader_templateId(&hdr);
    if (template_id == shm_tensorpool_driver_shmAttachResponse_sbe_template_id())
    {
        tp_decode_attach_response(driver, buf, length);
    }
    else if (template_id == shm_tensorpool_driver_shmDetachResponse_sbe_template_id())
    {
        tp_decode_detach_response(driver, buf, length);
    }
}

tp_err_t tp_driver_client_init(tp_client_t *client)
{
    tp_driver_client_t *driver = &client->driver;
    memset(driver, 0, sizeof(*driver));

    if (tp_add_publication(client->aeron, client->context->control_channel, client->context->control_stream_id, &driver->pub) < 0)
    {
        return TP_ERR_AERON;
    }
    if (tp_add_subscription(client->aeron, client->context->control_channel, client->context->control_stream_id, &driver->sub) < 0)
    {
        return TP_ERR_AERON;
    }

    if (aeron_fragment_assembler_create(&driver->assembler, tp_driver_fragment_handler, driver) < 0)
    {
        return TP_ERR_AERON;
    }
    return TP_OK;
}

void tp_driver_client_close(tp_driver_client_t *driver)
{
    if (driver->assembler)
    {
        aeron_fragment_assembler_delete(driver->assembler);
    }
    if (driver->sub)
    {
        aeron_subscription_close(driver->sub, NULL, NULL);
    }
    if (driver->pub)
    {
        aeron_publication_close(driver->pub, NULL, NULL);
    }
    memset(driver, 0, sizeof(*driver));
}

int tp_driver_poll(tp_client_t *client, int fragment_limit)
{
    if (client == NULL)
    {
        return 0;
    }
    return aeron_subscription_poll(
        client->driver.sub,
        aeron_fragment_assembler_handler,
        client->driver.assembler,
        (size_t)fragment_limit);
}
