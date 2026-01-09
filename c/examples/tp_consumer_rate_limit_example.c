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
    env = getenv("TP_CONSUMER_MAX_RATE_HZ");
    uint64_t max_rate_hz = env ? (uint64_t)strtoull(env, NULL, 10) : 0;
    env = getenv("TP_CONSUMER_MODE");
    uint8_t mode = env ? (uint8_t)strtoul(env, NULL, 10) : TP_CONSUMER_MODE_STREAM;

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

    const char *req_descriptor_channel = getenv("TP_CONSUMER_DESCRIPTOR_CHANNEL");
    const char *req_control_channel = getenv("TP_CONSUMER_CONTROL_CHANNEL");
    env = getenv("TP_CONSUMER_DESCRIPTOR_STREAM_ID");
    int32_t req_descriptor_stream_id = env ? (int32_t)strtoul(env, NULL, 10) : 0;
    env = getenv("TP_CONSUMER_CONTROL_STREAM_ID");
    int32_t req_control_stream_id = env ? (int32_t)strtoul(env, NULL, 10) : 0;
    if (req_descriptor_channel && req_descriptor_channel[0] != '\0' && req_descriptor_stream_id != 0)
    {
        tp_context_set_consumer_descriptor_request(ctx, req_descriptor_channel, req_descriptor_stream_id);
    }
    if (req_control_channel && req_control_channel[0] != '\0' && req_control_stream_id != 0)
    {
        tp_context_set_consumer_control_request(ctx, req_control_channel, req_control_stream_id);
    }
    if (max_rate_hz > 0)
    {
        tp_context_set_consumer_max_rate_hz(ctx, max_rate_hz);
    }
    tp_context_set_consumer_mode(ctx, mode);
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

    uint64_t deadline = now_ns() + 2000000000ULL;
    while (now_ns() < deadline)
    {
        tp_client_do_work(client);
        tp_consumer_poll(consumer, 10);
    }

    tp_consumer_close(consumer);
    tp_client_close(client);
    tp_context_close(ctx);
    return 0;
}
