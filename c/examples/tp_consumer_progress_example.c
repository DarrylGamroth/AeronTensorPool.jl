#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

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
    env = getenv("TP_PROGRESS_TIMEOUT_MS");
    uint64_t timeout_ns = env ? (uint64_t)strtoull(env, NULL, 10) * 1000000ULL : 5000000000ULL;

    tp_context_t *ctx = NULL;
    tp_client_t *client = NULL;
    tp_consumer_t *consumer = NULL;

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
    const char *descriptor_channel = getenv("TP_DESCRIPTOR_CHANNEL");
    if (descriptor_channel && descriptor_channel[0] != '\0')
    {
        tp_context_set_descriptor_channel(ctx, descriptor_channel);
    }
    env = getenv("TP_CONTROL_STREAM_ID");
    if (env && env[0] != '\0')
    {
        tp_context_set_control_stream_id(ctx, (uint32_t)strtoul(env, NULL, 10));
    }
    env = getenv("TP_DESCRIPTOR_STREAM_ID");
    if (env && env[0] != '\0')
    {
        tp_context_set_descriptor_stream_id(ctx, (uint32_t)strtoul(env, NULL, 10));
    }
    tp_context_set_attach_timeout_ns(ctx, attach_timeout_ns);

    if (tp_client_connect(ctx, &client) != TP_OK)
    {
        fprintf(stderr, "client connect failed\n");
        tp_context_close(ctx);
        return 1;
    }

    if (tp_attach_consumer(client, stream_id, &consumer) != TP_OK)
    {
        fprintf(stderr, "attach consumer failed\n");
        tp_client_close(client);
        tp_context_close(ctx);
        return 1;
    }

    uint64_t deadline = now_ns() + timeout_ns;
    while (now_ns() < deadline)
    {
        tp_client_do_work(client);
        tp_consumer_poll(consumer, 10);
        uint64_t frame_id = 0;
        uint64_t bytes_filled = 0;
        uint8_t state = 0;
        bool available = false;
        if (tp_consumer_get_progress(consumer, &frame_id, &bytes_filled, &state, &available) == TP_OK && available)
        {
            printf("progress frame=%llu bytes=%llu state=%u\n",
                (unsigned long long)frame_id,
                (unsigned long long)bytes_filled,
                (unsigned int)state);
            break;
        }
    }

    tp_consumer_close(consumer);
    tp_client_close(client);
    tp_context_close(ctx);
    return 0;
}
