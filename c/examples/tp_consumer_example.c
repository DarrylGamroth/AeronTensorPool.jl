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
    uint32_t stream_id = env ? (uint32_t)strtoul(env, NULL, 10) : 10000;
    env = getenv("TP_COUNT");
    uint32_t count = env ? (uint32_t)strtoul(env, NULL, 10) : 10;
    env = getenv("TP_ATTACH_TIMEOUT_MS");
    uint64_t attach_timeout_ns = env ? (uint64_t)strtoull(env, NULL, 10) * 1000000ULL : 5000000000ULL;
    env = getenv("TP_QOS_INTERVAL_MS");
    uint64_t qos_interval_ns = env ? (uint64_t)strtoull(env, NULL, 10) * 1000000ULL : 0;

    tp_context_t *ctx = NULL;
    tp_client_t *client = NULL;
    tp_consumer_t *consumer = NULL;
    tp_metadata_cache_t *metadata_cache = NULL;
    uint32_t last_meta_version = 0;

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
    const char *qos_channel = getenv("TP_QOS_CHANNEL");
    if (qos_channel && qos_channel[0] != '\0')
    {
        tp_context_set_qos_channel(ctx, qos_channel);
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
    env = getenv("TP_QOS_STREAM_ID");
    if (env && env[0] != '\0')
    {
        tp_context_set_qos_stream_id(ctx, (uint32_t)strtoul(env, NULL, 10));
    }
    tp_context_set_attach_timeout_ns(ctx, attach_timeout_ns);
    if (qos_interval_ns > 0)
    {
        tp_context_set_qos_interval_ns(ctx, qos_interval_ns);
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

    const char *metadata_channel = getenv("TP_METADATA_CHANNEL");
    const char *metadata_stream_env = getenv("TP_METADATA_STREAM_ID");
    if (metadata_channel && metadata_channel[0] != '\0' && metadata_stream_env && metadata_stream_env[0] != '\0')
    {
        int32_t metadata_stream_id = (int32_t)strtoul(metadata_stream_env, NULL, 10);
        if (tp_metadata_cache_init(client, metadata_channel, metadata_stream_id, &metadata_cache) != TP_OK)
        {
            fprintf(stderr, "metadata cache init failed\n");
            metadata_cache = NULL;
        }
    }

    const char *debug_sub_env = getenv("TP_DEBUG_SUB");
    const bool debug_sub = debug_sub_env != NULL && debug_sub_env[0] != '\0';
    uint64_t deadline = now_ns() + 5000000000ULL;
    uint32_t received = 0;
    tp_frame_view_t view;
    while (received < count && now_ns() < deadline)
    {
        tp_client_do_work(client);
        tp_consumer_poll(consumer, 10);
        if (metadata_cache)
        {
            tp_metadata_cache_poll(metadata_cache, 10);
            tp_metadata_entry_t entry;
            tp_err_t meta_err = tp_metadata_cache_get(metadata_cache, stream_id, &entry);
            if (meta_err == TP_OK && entry.meta_version != last_meta_version)
            {
                fprintf(stdout, "metadata v%u name='%s' summary='%s'\n", entry.meta_version, entry.name, entry.summary);
                last_meta_version = entry.meta_version;
            }
        }
        if (debug_sub && received == 0 && (now_ns() % 1000000000ULL) < 1000000ULL)
        {
            bool connected = tp_consumer_is_connected(consumer);
            fprintf(stderr, "consumer descriptor connected=%s\n", connected ? "true" : "false");
        }
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

    if (metadata_cache)
    {
        tp_metadata_cache_close(metadata_cache);
    }
    tp_consumer_close(consumer);
    tp_client_close(client);
    tp_context_close(ctx);
    return received == count ? 0 : 1;
}
