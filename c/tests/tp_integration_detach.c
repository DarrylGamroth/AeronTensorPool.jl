#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

#include "tensorpool_client.h"
#include "tp_internal.h"

static uint64_t now_ns(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;
}

static bool wait_for_driver_connect(tp_client_t *client, uint64_t timeout_ns)
{
    const uint64_t deadline = now_ns() + timeout_ns;
    while (now_ns() < deadline)
    {
        tp_client_do_work(client);
        if (client->driver.pub && aeron_publication_is_connected(client->driver.pub) &&
            client->driver.sub && aeron_subscription_is_connected(client->driver.sub))
        {
            return true;
        }
        usleep(1000);
    }
    return false;
}

int main(int argc, char **argv)
{
    (void)argc;
    (void)argv;

    const char *env = getenv("TP_STREAM_ID");
    uint32_t stream_id = env ? (uint32_t)strtoul(env, NULL, 10) : 10000;
    env = getenv("TP_ATTACH_TIMEOUT_MS");
    uint64_t attach_timeout_ns = env ? (uint64_t)strtoull(env, NULL, 10) * 1000000ULL : 30000000000ULL;
    env = getenv("TP_DETACH_TIMEOUT_MS");
    uint64_t detach_timeout_ns = env ? (uint64_t)strtoull(env, NULL, 10) * 1000000ULL : attach_timeout_ns;

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
    const char *control_stream = getenv("TP_CONTROL_STREAM_ID");
    if (control_stream && control_stream[0] != '\0')
    {
        tp_context_set_control_stream_id(ctx, (int32_t)strtol(control_stream, NULL, 10));
    }
    tp_context_set_attach_timeout_ns(ctx, attach_timeout_ns);
    tp_context_set_detach_timeout_ns(ctx, detach_timeout_ns);

    if (tp_client_connect(ctx, &client) != TP_OK)
    {
        fprintf(stderr, "client connect failed\n");
        tp_context_close(ctx);
        return 1;
    }

    if (!wait_for_driver_connect(client, attach_timeout_ns))
    {
        fprintf(stderr, "driver control not connected\n");
        tp_client_close(client);
        tp_context_close(ctx);
        return 1;
    }

    if (tp_attach_producer(client, stream_id, &producer) != TP_OK)
    {
        fprintf(stderr, "attach producer failed (code=%d, error=\"%s\")\n",
            client->driver.last_attach.code,
            client->driver.last_attach.error_message);
        tp_client_close(client);
        tp_context_close(ctx);
        return 1;
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

    tp_err_t err = tp_detach(client, lease_id, stream_id, client_id, TP_ROLE_PRODUCER);
    if (err != TP_OK)
    {
        fprintf(stderr, "detach failed (%s)\n", tp_err_str(err));
        tp_producer_close(producer);
        tp_client_close(client);
        tp_context_close(ctx);
        return 1;
    }

    tp_producer_close(producer);
    tp_client_close(client);
    tp_context_close(ctx);
    return 0;
}
