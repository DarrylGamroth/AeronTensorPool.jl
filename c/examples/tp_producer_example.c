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
    env = getenv("TP_PAYLOAD_BYTES");
    uint32_t payload_bytes = env ? (uint32_t)strtoul(env, NULL, 10) : 1024;
    env = getenv("TP_COUNT");
    uint32_t count = env ? (uint32_t)strtoul(env, NULL, 10) : 10;
    env = getenv("TP_SEND_DELAY_MS");
    uint32_t send_delay_ms = env ? (uint32_t)strtoul(env, NULL, 10) : 0;

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

    uint8_t *payload = (uint8_t *)malloc(payload_bytes);
    if (payload == NULL)
    {
        fprintf(stderr, "payload alloc failed\n");
        tp_producer_close(producer);
        tp_client_close(client);
        tp_context_close(ctx);
        return 1;
    }
    for (uint32_t i = 0; i < payload_bytes; i++)
    {
        payload[i] = (uint8_t)(i & 0xFF);
    }

    tp_tensor_header_t tensor;
    memset(&tensor, 0, sizeof(tensor));
    tensor.dtype = 1;
    tensor.major_order = 0;
    tensor.ndims = 1;
    tensor.dims[0] = (int32_t)payload_bytes;
    tensor.strides[0] = 1;

    if (send_delay_ms > 0)
    {
        usleep(send_delay_ms * 1000);
    }

    uint64_t deadline = now_ns() + 5000000000ULL;
    const char *debug_conn_env = getenv("TP_DEBUG_CONN");
    const bool debug_conn = debug_conn_env != NULL && debug_conn_env[0] != '\0';
    uint32_t sent = 0;
    uint32_t drops = 0;
    bool printed_error = false;
    while (sent < count && now_ns() < deadline)
    {
        tp_client_do_work(client);
        if (debug_conn && sent == 0 && (now_ns() % 1000000000ULL) < 1000000ULL)
        {
            bool connected = tp_producer_is_connected(producer);
            fprintf(stderr, "producer descriptor connected=%s\n", connected ? "true" : "false");
        }
        tp_slot_claim_t claim;
        tp_err_t claim_err = tp_producer_try_claim_slot_by_size(producer, payload_bytes, &claim);
        if (claim_err != TP_OK)
        {
            continue;
        }
        memcpy(claim.ptr, payload, payload_bytes);
        tp_err_t commit_err = tp_producer_commit_slot(producer, &claim, payload_bytes, &tensor, 1);
        if (commit_err != TP_OK)
        {
            if (!printed_error)
            {
                fprintf(stderr, "commit_slot failed (err=%d)\n", commit_err);
                printed_error = true;
            }
            drops++;
            usleep(1000);
            continue;
        }
        sent++;
    }

    fprintf(stdout, "sent %u frames (drops=%u)\n", sent, drops);

    free(payload);
    tp_producer_close(producer);
    tp_client_close(client);
    tp_context_close(ctx);
    return sent == count ? 0 : 1;
}
