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

    const char *qos_channel = getenv("TP_QOS_CHANNEL");
    const char *env = getenv("TP_QOS_STREAM_ID");
    int32_t qos_stream_id = env ? (int32_t)strtoul(env, NULL, 10) : 0;
    env = getenv("TP_QOS_PRODUCER_ID");
    uint32_t producer_id = env ? (uint32_t)strtoul(env, NULL, 10) : 0;
    env = getenv("TP_QOS_CONSUMER_ID");
    uint32_t consumer_id = env ? (uint32_t)strtoul(env, NULL, 10) : 0;
    env = getenv("TP_QOS_TIMEOUT_MS");
    uint64_t timeout_ns = env ? (uint64_t)strtoull(env, NULL, 10) * 1000000ULL : 5000000000ULL;

    if (qos_channel == NULL || qos_channel[0] == '\0' || qos_stream_id == 0)
    {
        fprintf(stderr, "set TP_QOS_CHANNEL and TP_QOS_STREAM_ID\n");
        return 1;
    }

    tp_context_t *ctx = NULL;
    tp_client_t *client = NULL;
    tp_qos_monitor_t *monitor = NULL;

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
    if (tp_client_connect(ctx, &client) != TP_OK)
    {
        fprintf(stderr, "client connect failed\n");
        tp_context_close(ctx);
        return 1;
    }
    if (tp_qos_monitor_init(client, qos_channel, qos_stream_id, &monitor) != TP_OK)
    {
        fprintf(stderr, "qos monitor init failed\n");
        tp_client_close(client);
        tp_context_close(ctx);
        return 1;
    }

    uint64_t deadline = now_ns() + timeout_ns;
    bool printed = false;
    while (now_ns() < deadline)
    {
        tp_client_do_work(client);
        tp_qos_monitor_poll(monitor, 10);
        if (producer_id != 0)
        {
            tp_qos_producer_snapshot_t snap;
            if (tp_qos_monitor_get_producer(monitor, producer_id, &snap) == TP_OK)
            {
                printf("producer qos stream=%u seq=%llu watermark=%llu\n",
                    snap.stream_id,
                    (unsigned long long)snap.current_seq,
                    (unsigned long long)snap.watermark);
                printed = true;
            }
        }
        if (consumer_id != 0)
        {
            tp_qos_consumer_snapshot_t snap;
            if (tp_qos_monitor_get_consumer(monitor, consumer_id, &snap) == TP_OK)
            {
                printf("consumer qos stream=%u last=%llu drops_gap=%llu drops_late=%llu\n",
                    snap.stream_id,
                    (unsigned long long)snap.last_seq_seen,
                    (unsigned long long)snap.drops_gap,
                    (unsigned long long)snap.drops_late);
                printed = true;
            }
        }
        if (printed)
        {
            break;
        }
    }

    tp_qos_monitor_close(monitor);
    tp_client_close(client);
    tp_context_close(ctx);
    return 0;
}
