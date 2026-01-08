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
    tmp->client_id = (uint32_t)getpid();
    tmp->use_invoker = false;
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
    if (dst == NULL || src == NULL || dst_len == 0)
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
