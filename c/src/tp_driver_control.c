#include "tp_internal.h"
#include <sched.h>
#include <stdio.h>

int tp_add_publication(aeron_t *client, const char *channel, int32_t stream_id, aeron_publication_t **pub)
{
    aeron_async_add_publication_t *async = NULL;
    if (aeron_async_add_publication(&async, client, channel, stream_id) < 0)
    {
        return -1;
    }
    while (aeron_async_add_publication_poll(pub, async) == 0)
    {
        sched_yield();
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
        sched_yield();
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

tp_err_t tp_validate_attach_response(const tp_attach_response_t *resp)
{
    if (resp == NULL)
    {
        return TP_ERR_ARG;
    }
    if (resp->code != shm_tensorpool_driver_responseCode_OK)
    {
        return TP_OK;
    }

    if (resp->lease_id == shm_tensorpool_driver_shmAttachResponse_leaseId_null_value() ||
        resp->stream_id == shm_tensorpool_driver_shmAttachResponse_streamId_null_value() ||
        resp->epoch == shm_tensorpool_driver_shmAttachResponse_epoch_null_value() ||
        resp->layout_version == shm_tensorpool_driver_shmAttachResponse_layoutVersion_null_value() ||
        resp->header_nslots == shm_tensorpool_driver_shmAttachResponse_headerNslots_null_value() ||
        resp->header_slot_bytes == shm_tensorpool_driver_shmAttachResponse_headerSlotBytes_null_value() ||
        resp->max_dims == shm_tensorpool_driver_shmAttachResponse_maxDims_null_value())
    {
        return TP_ERR_PROTOCOL;
    }

    if (resp->header_slot_bytes != TP_HEADER_SLOT_BYTES)
    {
        return TP_ERR_PROTOCOL;
    }
    if (resp->max_dims != shm_tensorpool_control_tensorHeader_maxDims())
    {
        return TP_ERR_PROTOCOL;
    }
    if (resp->header_nslots == 0)
    {
        return TP_ERR_PROTOCOL;
    }
    if (resp->pool_count == 0 || resp->pool_count > TP_MAX_POOLS)
    {
        return TP_ERR_PROTOCOL;
    }
    if (resp->header_uri[0] == '\0')
    {
        return TP_ERR_PROTOCOL;
    }

    for (uint32_t i = 0; i < resp->pool_count; i++)
    {
        if (resp->pools[i].pool_id == shm_tensorpool_driver_shmAttachResponse_payloadPools_poolId_null_value() ||
            resp->pools[i].nslots == shm_tensorpool_driver_shmAttachResponse_payloadPools_poolNslots_null_value() ||
            resp->pools[i].stride_bytes == shm_tensorpool_driver_shmAttachResponse_payloadPools_strideBytes_null_value())
        {
            return TP_ERR_PROTOCOL;
        }
        if (resp->pools[i].nslots != resp->header_nslots)
        {
            return TP_ERR_PROTOCOL;
        }
        if (resp->pools[i].stride_bytes == 0)
        {
            return TP_ERR_PROTOCOL;
        }
        if (resp->pools[i].uri[0] == '\0')
        {
            return TP_ERR_PROTOCOL;
        }
    }
    return TP_OK;
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
    enum shm_tensorpool_driver_responseCode code_val;
    if (!shm_tensorpool_driver_shmAttachResponse_code(&resp, &code_val))
    {
        driver->last_attach_valid = false;
        driver->last_attach_correlation = out->correlation_id;
        return;
    }
    out->code = (int32_t)code_val;
    out->lease_id = shm_tensorpool_driver_shmAttachResponse_leaseId(&resp);
    out->lease_expiry_ns = shm_tensorpool_driver_shmAttachResponse_leaseExpiryTimestampNs(&resp);
    out->stream_id = shm_tensorpool_driver_shmAttachResponse_streamId(&resp);
    out->epoch = shm_tensorpool_driver_shmAttachResponse_epoch(&resp);
    out->layout_version = shm_tensorpool_driver_shmAttachResponse_layoutVersion(&resp);
    out->header_nslots = shm_tensorpool_driver_shmAttachResponse_headerNslots(&resp);
    out->header_slot_bytes = shm_tensorpool_driver_shmAttachResponse_headerSlotBytes(&resp);
    out->max_dims = shm_tensorpool_driver_shmAttachResponse_maxDims(&resp);

    struct shm_tensorpool_driver_shmAttachResponse_payloadPools pools;
    uint64_t *pos = shm_tensorpool_driver_shmAttachResponse_sbe_position_ptr(&resp);
    uint16_t block_len = 0;
    uint16_t count = 0;
    if (*pos + 4 <= resp.buffer_length)
    {
        memcpy(&block_len, resp.buffer + *pos, sizeof(uint16_t));
        memcpy(&count, resp.buffer + *pos + 2, sizeof(uint16_t));
    }

    bool group_first = block_len == shm_tensorpool_driver_shmAttachResponse_payloadPools_sbe_block_length();
    if (!group_first)
    {
        uint32_t header_len = shm_tensorpool_driver_shmAttachResponse_headerRegionUri_length(&resp);
        const char *header_uri = shm_tensorpool_driver_shmAttachResponse_headerRegionUri(&resp);
        tp_copy_ascii(out->header_uri, sizeof(out->header_uri), header_uri, header_len);

        uint32_t err_len = shm_tensorpool_driver_shmAttachResponse_errorMessage_length(&resp);
        const char *err_msg = shm_tensorpool_driver_shmAttachResponse_errorMessage(&resp);
        tp_copy_ascii(out->error_message, sizeof(out->error_message), err_msg, err_len);
    }

    bool invalid_pool_count = false;
    if (shm_tensorpool_driver_shmAttachResponse_payloadPools_wrap_for_decode(&pools, resp.buffer, pos, acting_version, resp.buffer_length))
    {
        uint32_t group_count = (uint32_t)shm_tensorpool_driver_shmAttachResponse_payloadPools_count(&pools);
        if (group_count > TP_MAX_POOLS)
        {
            invalid_pool_count = true;
            group_count = TP_MAX_POOLS;
        }
        out->pool_count = group_count;
        for (uint32_t i = 0; i < group_count && shm_tensorpool_driver_shmAttachResponse_payloadPools_has_next(&pools); i++)
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

    if (group_first)
    {
        uint32_t header_len = shm_tensorpool_driver_shmAttachResponse_headerRegionUri_length(&resp);
        const char *header_uri = shm_tensorpool_driver_shmAttachResponse_headerRegionUri(&resp);
        tp_copy_ascii(out->header_uri, sizeof(out->header_uri), header_uri, header_len);

        uint32_t err_len = shm_tensorpool_driver_shmAttachResponse_errorMessage_length(&resp);
        const char *err_msg = shm_tensorpool_driver_shmAttachResponse_errorMessage(&resp);
        tp_copy_ascii(out->error_message, sizeof(out->error_message), err_msg, err_len);
    }

    if (invalid_pool_count)
    {
        driver->last_attach_valid = false;
    }
    else
    {
        driver->last_attach_valid = (tp_validate_attach_response(out) == TP_OK);
    }
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
    enum shm_tensorpool_driver_responseCode code_val;
    if (!shm_tensorpool_driver_shmDetachResponse_code(&resp, &code_val))
    {
        return;
    }
    driver->last_detach_code = (int32_t)code_val;
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
    else if (template_id == shm_tensorpool_driver_shmLeaseRevoked_sbe_template_id())
    {
        struct shm_tensorpool_driver_shmLeaseRevoked msg;
        const uint64_t acting_block_length = shm_tensorpool_driver_messageHeader_blockLength(&hdr);
        const uint64_t acting_version = shm_tensorpool_driver_messageHeader_version(&hdr);
        shm_tensorpool_driver_shmLeaseRevoked_wrap_for_decode(
            &msg,
            buf + shm_tensorpool_driver_messageHeader_encoded_length(),
            0,
            acting_block_length,
            acting_version,
            length - shm_tensorpool_driver_messageHeader_encoded_length());
        enum shm_tensorpool_driver_role role_val;
        enum shm_tensorpool_driver_leaseRevokeReason reason_val;
        if (!shm_tensorpool_driver_shmLeaseRevoked_role(&msg, &role_val))
        {
            return;
        }
        if (!shm_tensorpool_driver_shmLeaseRevoked_reason(&msg, &reason_val))
        {
            return;
        }
        driver->revoked_lease_id = shm_tensorpool_driver_shmLeaseRevoked_leaseId(&msg);
        driver->revoked_stream_id = shm_tensorpool_driver_shmLeaseRevoked_streamId(&msg);
        driver->revoked_role = (uint8_t)role_val;
        driver->revoked_reason = (uint8_t)reason_val;
    }
    else if (template_id == shm_tensorpool_driver_shmDriverShutdown_sbe_template_id())
    {
        struct shm_tensorpool_driver_shmDriverShutdown msg;
        const uint64_t acting_block_length = shm_tensorpool_driver_messageHeader_blockLength(&hdr);
        const uint64_t acting_version = shm_tensorpool_driver_messageHeader_version(&hdr);
        shm_tensorpool_driver_shmDriverShutdown_wrap_for_decode(
            &msg,
            buf + shm_tensorpool_driver_messageHeader_encoded_length(),
            0,
            acting_block_length,
            acting_version,
            length - shm_tensorpool_driver_messageHeader_encoded_length());
        enum shm_tensorpool_driver_shutdownReason reason_val;
        if (!shm_tensorpool_driver_shmDriverShutdown_reason(&msg, &reason_val))
        {
            return;
        }
        driver->shutdown = true;
        driver->shutdown_reason = (uint8_t)reason_val;
    }
}

tp_err_t tp_driver_client_init(tp_client_t *client)
{
    tp_driver_client_t *driver = &client->driver;
    memset(driver, 0, sizeof(*driver));
    driver->last_attach_valid = false;

    if (tp_add_publication(client->aeron, client->context->control_channel, client->context->control_stream_id, &driver->pub) < 0)
    {
        const char *debug_env = getenv("TP_DEBUG_AERON");
        if (debug_env != NULL && debug_env[0] != '\0')
        {
            fprintf(stderr, "driver client add publication failed: %d %s\n", aeron_errcode(), aeron_errmsg());
        }
        return TP_ERR_AERON;
    }
    if (tp_add_subscription(client->aeron, client->context->control_channel, client->context->control_stream_id, &driver->sub) < 0)
    {
        const char *debug_env = getenv("TP_DEBUG_AERON");
        if (debug_env != NULL && debug_env[0] != '\0')
        {
            fprintf(stderr, "driver client add subscription failed: %d %s\n", aeron_errcode(), aeron_errmsg());
        }
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
