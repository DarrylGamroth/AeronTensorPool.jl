#include "tp_internal.h"
#include <stdio.h>
#include <unistd.h>

tp_err_t tp_context_init(tp_context_t **ctx)
{
    if (ctx == NULL)
    {
        return TP_ERR_ARG;
    }
    tp_context_t *tmp = (tp_context_t *)calloc(1, sizeof(tp_context_t));
    if (tmp == NULL)
    {
        return TP_ERR_NOMEM;
    }
    tmp->aeron_dir[0] = '\0';
    snprintf(tmp->control_channel, sizeof(tmp->control_channel), "%s", "aeron:ipc?term-length=4m");
    tmp->control_stream_id = 1000;
    snprintf(tmp->descriptor_channel, sizeof(tmp->descriptor_channel), "%s", "aeron:ipc?term-length=4m");
    tmp->descriptor_stream_id = 1100;
    tmp->qos_channel[0] = '\0';
    tmp->qos_stream_id = 0;
    tmp->client_id = (uint32_t)getpid();
    tmp->use_invoker = false;
    tmp->attach_timeout_ns = 5000000000ULL;
    tmp->detach_timeout_ns = 5000000000ULL;
    tmp->qos_interval_ns = 1000000000ULL;
    tmp->lease_keepalive_interval_ns = 1000000000ULL;
    tmp->announce_freshness_ns = 3000000000ULL;
    tmp->consumer_mode = shm_tensorpool_control_mode_STREAM;
    tmp->consumer_max_rate_hz = shm_tensorpool_control_consumerHello_maxRateHz_null_value();
    tmp->consumer_descriptor_channel[0] = '\0';
    tmp->consumer_descriptor_stream_id = 0;
    tmp->consumer_control_channel[0] = '\0';
    tmp->consumer_control_stream_id = 0;
    *ctx = tmp;
    return TP_OK;
}

void tp_context_close(tp_context_t *ctx)
{
    if (ctx)
    {
        free(ctx);
    }
}

static tp_err_t tp_set_string(char *dst, size_t dst_len, const char *src)
{
    if ((dst == NULL) || (src == NULL) || (dst_len == 0))
    {
        return TP_ERR_ARG;
    }
    snprintf(dst, dst_len, "%s", src);
    return TP_OK;
}

tp_err_t tp_context_set_aeron_dir(tp_context_t *ctx, const char *aeron_dir)
{
    if (ctx == NULL)
    {
        return TP_ERR_ARG;
    }
    return tp_set_string(ctx->aeron_dir, sizeof(ctx->aeron_dir), aeron_dir);
}

tp_err_t tp_context_set_control_channel(tp_context_t *ctx, const char *channel)
{
    if (ctx == NULL)
    {
        return TP_ERR_ARG;
    }
    return tp_set_string(ctx->control_channel, sizeof(ctx->control_channel), channel);
}

tp_err_t tp_context_set_control_stream_id(tp_context_t *ctx, int32_t stream_id)
{
    if (ctx == NULL)
    {
        return TP_ERR_ARG;
    }
    ctx->control_stream_id = stream_id;
    return TP_OK;
}

tp_err_t tp_context_set_descriptor_channel(tp_context_t *ctx, const char *channel)
{
    if (ctx == NULL)
    {
        return TP_ERR_ARG;
    }
    return tp_set_string(ctx->descriptor_channel, sizeof(ctx->descriptor_channel), channel);
}

tp_err_t tp_context_set_descriptor_stream_id(tp_context_t *ctx, int32_t stream_id)
{
    if (ctx == NULL)
    {
        return TP_ERR_ARG;
    }
    ctx->descriptor_stream_id = stream_id;
    return TP_OK;
}

tp_err_t tp_context_set_qos_channel(tp_context_t *ctx, const char *channel)
{
    if (ctx == NULL)
    {
        return TP_ERR_ARG;
    }
    return tp_set_string(ctx->qos_channel, sizeof(ctx->qos_channel), channel);
}

tp_err_t tp_context_set_qos_stream_id(tp_context_t *ctx, int32_t stream_id)
{
    if (ctx == NULL)
    {
        return TP_ERR_ARG;
    }
    ctx->qos_stream_id = stream_id;
    return TP_OK;
}

tp_err_t tp_context_set_client_id(tp_context_t *ctx, uint32_t client_id)
{
    if (ctx == NULL)
    {
        return TP_ERR_ARG;
    }
    ctx->client_id = client_id;
    return TP_OK;
}

tp_err_t tp_context_set_use_invoker(tp_context_t *ctx, bool value)
{
    if (ctx == NULL)
    {
        return TP_ERR_ARG;
    }
    ctx->use_invoker = value;
    return TP_OK;
}

tp_err_t tp_context_set_attach_timeout_ns(tp_context_t *ctx, uint64_t timeout_ns)
{
    if (ctx == NULL)
    {
        return TP_ERR_ARG;
    }
    ctx->attach_timeout_ns = timeout_ns;
    return TP_OK;
}

tp_err_t tp_context_set_qos_interval_ns(tp_context_t *ctx, uint64_t interval_ns)
{
    if (ctx == NULL)
    {
        return TP_ERR_ARG;
    }
    ctx->qos_interval_ns = interval_ns;
    return TP_OK;
}

tp_err_t tp_context_set_detach_timeout_ns(tp_context_t *ctx, uint64_t timeout_ns)
{
    if (ctx == NULL)
    {
        return TP_ERR_ARG;
    }
    ctx->detach_timeout_ns = timeout_ns;
    return TP_OK;
}

tp_err_t tp_context_set_announce_freshness_ns(tp_context_t *ctx, uint64_t freshness_ns)
{
    if (ctx == NULL)
    {
        return TP_ERR_ARG;
    }
    ctx->announce_freshness_ns = freshness_ns;
    return TP_OK;
}

tp_err_t tp_context_set_lease_keepalive_interval_ns(tp_context_t *ctx, uint64_t interval_ns)
{
    if (ctx == NULL)
    {
        return TP_ERR_ARG;
    }
    ctx->lease_keepalive_interval_ns = interval_ns;
    return TP_OK;
}

tp_err_t tp_context_set_consumer_mode(tp_context_t *ctx, uint8_t mode)
{
    if (ctx == NULL)
    {
        return TP_ERR_ARG;
    }
    if (mode != shm_tensorpool_control_mode_STREAM &&
        mode != shm_tensorpool_control_mode_RATE_LIMITED)
    {
        return TP_ERR_ARG;
    }
    ctx->consumer_mode = mode;
    return TP_OK;
}

tp_err_t tp_context_set_consumer_max_rate_hz(tp_context_t *ctx, uint64_t rate_hz)
{
    if (ctx == NULL)
    {
        return TP_ERR_ARG;
    }
    ctx->consumer_max_rate_hz = rate_hz;
    return TP_OK;
}

tp_err_t tp_context_set_consumer_descriptor_request(tp_context_t *ctx, const char *channel, int32_t stream_id)
{
    if ((ctx == NULL) || (channel == NULL))
    {
        return TP_ERR_ARG;
    }
    snprintf(ctx->consumer_descriptor_channel, sizeof(ctx->consumer_descriptor_channel), "%s", channel);
    ctx->consumer_descriptor_stream_id = stream_id;
    return TP_OK;
}

tp_err_t tp_context_set_consumer_control_request(tp_context_t *ctx, const char *channel, int32_t stream_id)
{
    if ((ctx == NULL) || (channel == NULL))
    {
        return TP_ERR_ARG;
    }
    snprintf(ctx->consumer_control_channel, sizeof(ctx->consumer_control_channel), "%s", channel);
    ctx->consumer_control_stream_id = stream_id;
    return TP_OK;
}
