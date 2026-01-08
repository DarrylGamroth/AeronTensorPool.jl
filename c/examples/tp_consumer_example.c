#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
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
    uint32_t stream_id = env ? (uint32_t)strtoul(env, NULL, 10) : 1000;
    env = getenv("TP_COUNT");
    uint32_t count = env ? (uint32_t)strtoul(env, NULL, 10) : 10;

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

    uint64_t deadline = now_ns() + 5000000000ULL;
    uint32_t received = 0;
    tp_frame_view_t view;
    while (received < count && now_ns() < deadline)
    {
        tp_client_do_work(client);
        tp_consumer_poll(consumer, 10);
        tp_err_t read_err = tp_consumer_try_read_frame(consumer, &view);
        if (read_err == TP_OK)
        {
            received++;
        }
        else if (read_err != TP_ERR_TIMEOUT)
        {
            fprintf(stderr, "read frame failed (err=%d)\n", read_err);
            break;
        }
    }

    fprintf(stdout, "received %u frames\n", received);

    tp_consumer_close(consumer);
    tp_client_close(client);
    tp_context_close(ctx);
    return received == count ? 0 : 1;
}
