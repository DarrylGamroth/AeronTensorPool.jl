#include "tp_internal.h"
#include <stdio.h>
#include <time.h>

uint64_t tp_now_ns(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;
}

uint64_t tp_now_realtime_ns(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;
}

tp_err_t tp_client_connect(tp_context_t *ctx, tp_client_t **client)
{
    if ((ctx == NULL) || (client == NULL))
    {
        return TP_ERR_ARG;
    }

    tp_client_t *tp = (tp_client_t *)calloc(1, sizeof(tp_client_t));
    if (tp == NULL)
    {
        return TP_ERR_NOMEM;
    }

    aeron_context_t *aeron_ctx = NULL;
    if (aeron_context_init(&aeron_ctx) < 0)
    {
        const char *debug_env = getenv("TP_DEBUG_AERON");
        if (debug_env != NULL && debug_env[0] != '\0')
        {
            fprintf(stderr, "aeron_context_init failed: %d %s\n", aeron_errcode(), aeron_errmsg());
        }
        free(tp);
        return TP_ERR_AERON;
    }

    if (ctx->aeron_dir[0] != '\0')
    {
        aeron_context_set_dir(aeron_ctx, ctx->aeron_dir);
    }
    if (ctx->use_invoker)
    {
        aeron_context_set_use_conductor_agent_invoker(aeron_ctx, true);
    }

    aeron_t *aeron = NULL;
    if (aeron_init(&aeron, aeron_ctx) < 0)
    {
        const char *debug_env = getenv("TP_DEBUG_AERON");
        if (debug_env != NULL && debug_env[0] != '\0')
        {
            fprintf(stderr, "aeron_init failed: %d %s\n", aeron_errcode(), aeron_errmsg());
        }
        aeron_context_close(aeron_ctx);
        free(tp);
        return TP_ERR_AERON;
    }

    if (aeron_start(aeron) < 0)
    {
        const char *debug_env = getenv("TP_DEBUG_AERON");
        if (debug_env != NULL && debug_env[0] != '\0')
        {
            fprintf(stderr, "aeron_start failed: %d %s\n", aeron_errcode(), aeron_errmsg());
        }
        aeron_close(aeron);
        aeron_context_close(aeron_ctx);
        free(tp);
        return TP_ERR_AERON;
    }

    tp->context = ctx;
    tp->aeron_ctx = aeron_ctx;
    tp->aeron = aeron;
    tp->next_correlation_id = 1;

    if (tp_driver_client_init(tp) != TP_OK)
    {
        const char *debug_env = getenv("TP_DEBUG_AERON");
        if (debug_env != NULL && debug_env[0] != '\0')
        {
            fprintf(stderr, "tp_driver_client_init failed: %d %s\n", aeron_errcode(), aeron_errmsg());
        }
        tp_client_close(tp);
        return TP_ERR_AERON;
    }

    *client = tp;
    return TP_OK;
}

void tp_client_close(tp_client_t *client)
{
    if (client == NULL)
    {
        return;
    }
    tp_driver_client_close(&client->driver);
    if (client->aeron)
    {
        aeron_close(client->aeron);
    }
    if (client->aeron_ctx)
    {
        aeron_context_close(client->aeron_ctx);
    }
    free(client);
}

int tp_client_do_work(tp_client_t *client)
{
    if (client == NULL)
    {
        return -1;
    }
    int work = 0;
    if (client->context->use_invoker)
    {
        work = aeron_main_do_work(client->aeron);
    }
    work += tp_driver_poll(client, 10);
    return work;
}

tp_err_t tp_client_get_client_id(const tp_client_t *client, uint32_t *client_id)
{
    if ((client == NULL) || (client_id == NULL))
    {
        return TP_ERR_ARG;
    }
    *client_id = client->context->client_id;
    return TP_OK;
}
