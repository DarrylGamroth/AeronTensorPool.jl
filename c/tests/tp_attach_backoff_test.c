#include <assert.h>
#include <pthread.h>
#include <sched.h>
#include <stdlib.h>
#include <string.h>

#include "tensorpool_client.h"
#include "tp_internal.h"

typedef struct attach_poll_ctx_stct
{
    aeron_subscription_t *sub;
    aeron_fragment_assembler_t *assembler;
    volatile int running;
    volatile int count;
}
attach_poll_ctx_t;

static void on_fragment(void *clientd, const uint8_t *buffer, size_t length, aeron_header_t *header)
{
    (void)header;
    attach_poll_ctx_t *ctx = (attach_poll_ctx_t *)clientd;
    if (length < shm_tensorpool_driver_messageHeader_encoded_length())
    {
        return;
    }
    struct shm_tensorpool_driver_messageHeader hdr;
    if (!shm_tensorpool_driver_messageHeader_wrap(
            &hdr, (char *)buffer, 0, shm_tensorpool_driver_messageHeader_sbe_schema_version(), length))
    {
        return;
    }
    if (shm_tensorpool_driver_messageHeader_templateId(&hdr) ==
        shm_tensorpool_driver_shmAttachRequest_sbe_template_id())
    {
        ctx->count += 1;
    }
}

static void *poll_loop(void *arg)
{
    attach_poll_ctx_t *ctx = (attach_poll_ctx_t *)arg;
    while (ctx->running)
    {
        aeron_subscription_poll(
            ctx->sub,
            aeron_fragment_assembler_handler,
            ctx->assembler,
            10);
        sched_yield();
    }
    return NULL;
}

int main(void)
{
    tp_context_t *ctx = NULL;
    tp_client_t *client = NULL;
    tp_consumer_t *consumer = NULL;

    assert(tp_context_init(&ctx) == TP_OK);
    tp_context_set_control_channel(ctx, "aeron:ipc");
    tp_context_set_control_stream_id(ctx, 18100);
    tp_context_set_attach_timeout_ns(ctx, 200000000);
    tp_context_set_attach_retry_interval_ns(ctx, 50000000);

    const char *aeron_dir = getenv("TP_AERON_DIR");
    if (aeron_dir && aeron_dir[0] != '\0')
    {
        tp_context_set_aeron_dir(ctx, aeron_dir);
    }

    assert(tp_client_connect(ctx, &client) == TP_OK);

    aeron_subscription_t *sub = NULL;
    assert(tp_add_subscription(client->aeron, "aeron:ipc", 18100, &sub) == 0);

    attach_poll_ctx_t poll_ctx;
    memset(&poll_ctx, 0, sizeof(poll_ctx));
    poll_ctx.sub = sub;
    poll_ctx.running = 1;
    assert(aeron_fragment_assembler_create(&poll_ctx.assembler, on_fragment, &poll_ctx) == 0);

    pthread_t thread;
    pthread_create(&thread, NULL, poll_loop, &poll_ctx);

    tp_err_t err = tp_attach_consumer(client, 10000, &consumer);
    assert(err == TP_ERR_TIMEOUT);
    poll_ctx.running = 0;
    pthread_join(thread, NULL);

    assert(poll_ctx.count >= 2);

    if (poll_ctx.assembler)
    {
        aeron_fragment_assembler_delete(poll_ctx.assembler);
    }
    if (sub)
    {
        aeron_subscription_close(sub, NULL, NULL);
    }
    tp_client_close(client);
    tp_context_close(ctx);
    return 0;
}
