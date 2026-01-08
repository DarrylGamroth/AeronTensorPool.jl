#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
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
    uint32_t stream_id = env ? (uint32_t)strtoul(env, NULL, 10) : 1000;

    tp_context_t *ctx = NULL;
    tp_client_t *client = NULL;
    tp_producer_t *producer = NULL;
    tp_consumer_t *consumer = NULL;

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
    if (tp_attach_consumer(client, stream_id, &consumer) != TP_OK)
    {
        fprintf(stderr, "attach consumer failed\n");
        tp_producer_close(producer);
        tp_client_close(client);
        tp_context_close(ctx);
        return 1;
    }

    uint8_t payload[16];
    for (uint32_t i = 0; i < sizeof(payload); i++)
    {
        payload[i] = (uint8_t)(i + 1);
    }

    tp_tensor_header_t tensor;
    memset(&tensor, 0, sizeof(tensor));
    tensor.dtype = 1;
    tensor.major_order = 0;
    tensor.ndims = 1;
    tensor.dims[0] = (int32_t)sizeof(payload);
    tensor.strides[0] = 1;

    if (tp_producer_offer_frame(producer, payload, (uint32_t)sizeof(payload), &tensor, 1) != TP_OK)
    {
        fprintf(stderr, "offer frame failed\n");
        tp_consumer_close(consumer);
        tp_producer_close(producer);
        tp_client_close(client);
        tp_context_close(ctx);
        return 1;
    }

    tp_frame_view_t view;
    uint64_t deadline = now_ns() + 2000000000ULL;
    while (now_ns() < deadline)
    {
        tp_client_do_work(client);
        tp_consumer_poll(consumer, 10);
        if (tp_consumer_try_read_frame(consumer, &view) == TP_OK)
        {
            if (view.payload_len != sizeof(payload))
            {
                fprintf(stderr, "payload length mismatch\n");
                break;
            }
            if (memcmp(view.payload, payload, sizeof(payload)) != 0)
            {
                fprintf(stderr, "payload mismatch\n");
                break;
            }
            tp_consumer_close(consumer);
            tp_producer_close(producer);
            tp_client_close(client);
            tp_context_close(ctx);
            return 0;
        }
    }

    fprintf(stderr, "timed out waiting for frame\n");
    tp_consumer_close(consumer);
    tp_producer_close(producer);
    tp_client_close(client);
    tp_context_close(ctx);
    return 1;
}
