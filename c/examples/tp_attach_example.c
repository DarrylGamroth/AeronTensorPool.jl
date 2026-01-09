#include <stdio.h>
#include <stdlib.h>

#include "tensorpool_client.h"

int main(int argc, char **argv)
{
    if (argc < 2)
    {
        fprintf(stderr, "usage: %s <stream-id>\n", argv[0]);
        return 1;
    }

    uint32_t stream_id = (uint32_t)strtoul(argv[1], NULL, 10);
    const char *env = getenv("TP_ATTACH_TIMEOUT_MS");
    uint64_t attach_timeout_ns = env ? (uint64_t)strtoull(env, NULL, 10) * 1000000ULL : 5000000000ULL;
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
    if (tp_attach_producer(client, stream_id, &producer) != TP_OK)
    {
        fprintf(stderr, "attach producer failed\n");
        tp_client_close(client);
        tp_context_close(ctx);
        return 1;
    }

    printf("attached producer for stream %u\n", stream_id);
    tp_producer_close(producer);
    tp_client_close(client);
    tp_context_close(ctx);
    return 0;
}
