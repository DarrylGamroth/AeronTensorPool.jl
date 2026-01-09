#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

#include "tensorpool_client.h"

static uint64_t now_ns(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;
}

int main(int argc, char **argv)
{
    (void)argc;
    (void)argv;

    const char *env = getenv("TP_STREAM_ID");
    uint32_t stream_id = env ? (uint32_t)strtoul(env, NULL, 10) : 10000;
    env = getenv("TP_ATTACH_TIMEOUT_MS");
    uint64_t attach_timeout_ns = env ? (uint64_t)strtoull(env, NULL, 10) * 1000000ULL : 5000000000ULL;
    env = getenv("TP_DETACH_DELAY_MS");
    uint64_t delay_ms = env ? (uint64_t)strtoull(env, NULL, 10) : 500;

    tp_context_t *ctx = NULL;
    tp_client_t *client = NULL;
    tp_producer_t *producer = NULL;

    if (tp_context_init(&ctx) != TP_OK)
    {
        fprintf(stderr, "context init failed\n");
        return 1;
    }
    const char *aeron_dir = getenv("TP_AERON_DIR");
    if (aeron_dir && aeron_dir[0] != '\0')
    {
        tp_context_set_aeron_dir(ctx, aeron_dir);
    }
    const char *control_channel = getenv("TP_CONTROL_CHANNEL");
    if (control_channel && control_channel[0] != '\0')
    {
        tp_context_set_control_channel(ctx, control_channel);
    }
    env = getenv("TP_CONTROL_STREAM_ID");
    if (env && env[0] != '\0')
    {
        tp_context_set_control_stream_id(ctx, (uint32_t)strtoul(env, NULL, 10));
    }
    tp_context_set_attach_timeout_ns(ctx, attach_timeout_ns);

    if (tp_client_connect(ctx, &client) != TP_OK)
    {
        fprintf(stderr, "client connect failed\n");
        tp_context_close(ctx);
        return 1;
    }
    if (tp_attach_producer(client, stream_id, &producer) != TP_OK)
    {
        fprintf(stderr, "attach producer failed\n");
        tp_client_close(client);
        tp_context_close(ctx);
        return 1;
    }

    uint64_t deadline = now_ns() + delay_ms * 1000000ULL;
    while (now_ns() < deadline)
    {
        tp_client_do_work(client);
        tp_producer_poll(producer);
        usleep(1000);
    }

    uint64_t lease_id = 0;
    uint32_t client_id = 0;
    if (tp_producer_get_lease_id(producer, &lease_id) != TP_OK ||
        tp_client_get_client_id(client, &client_id) != TP_OK)
    {
        fprintf(stderr, "failed to read lease/client id\n");
        tp_producer_close(producer);
        tp_client_close(client);
        tp_context_close(ctx);
        return 1;
    }
    tp_err_t err = tp_detach(
        client,
        lease_id,
        stream_id,
        client_id,
        TP_ROLE_PRODUCER);
    if (err != TP_OK)
    {
        fprintf(stderr, "detach failed (err=%d)\n", err);
    }
    else
    {
        printf("detach requested for stream %u lease %llu\n", stream_id, (unsigned long long)lease_id);
    }

    tp_producer_close(producer);
    tp_client_close(client);
    tp_context_close(ctx);
    return err == TP_OK ? 0 : 1;
}
