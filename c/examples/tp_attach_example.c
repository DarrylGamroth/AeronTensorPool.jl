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
    tp_context_t *ctx = NULL;
    tp_client_t *client = NULL;
    tp_producer_t *producer = NULL;

    if (tp_context_init(&ctx) != TP_OK)
    {
        fprintf(stderr, "context init failed\n");
        return 1;
    }
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
