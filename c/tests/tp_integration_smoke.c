#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
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

int main(int argc, char **argv)
{
    (void)argc;
    (void)argv;

    const char *env = getenv("TP_STREAM_ID");
    uint32_t stream_id = env ? (uint32_t)strtoul(env, NULL, 10) : 1000;

    tp_context_t *ctx_prod = NULL;
    tp_context_t *ctx_cons = NULL;
    tp_client_t *client_prod = NULL;
    tp_client_t *client_cons = NULL;
    tp_producer_t *producer = NULL;
    tp_consumer_t *consumer = NULL;

    if (tp_context_init(&ctx_prod) != TP_OK || tp_context_init(&ctx_cons) != TP_OK)
    {
        fprintf(stderr, "context init failed\n");
        return 1;
    }
    const char *aeron_dir = getenv("TP_AERON_DIR");
    if (aeron_dir && aeron_dir[0] != '\0')
    {
        tp_context_set_aeron_dir(ctx_prod, aeron_dir);
        tp_context_set_aeron_dir(ctx_cons, aeron_dir);
    }
    const char *control_channel = getenv("TP_CONTROL_CHANNEL");
    if (control_channel && control_channel[0] != '\0')
    {
        tp_context_set_control_channel(ctx_prod, control_channel);
        tp_context_set_control_channel(ctx_cons, control_channel);
    }
    const char *control_stream = getenv("TP_CONTROL_STREAM_ID");
    if (control_stream && control_stream[0] != '\0')
    {
        tp_context_set_control_stream_id(ctx_prod, (int32_t)strtol(control_stream, NULL, 10));
        tp_context_set_control_stream_id(ctx_cons, (int32_t)strtol(control_stream, NULL, 10));
    }
    const char *descriptor_channel = getenv("TP_DESCRIPTOR_CHANNEL");
    if (descriptor_channel && descriptor_channel[0] != '\0')
    {
        tp_context_set_descriptor_channel(ctx_prod, descriptor_channel);
        tp_context_set_descriptor_channel(ctx_cons, descriptor_channel);
    }
    const char *descriptor_stream = getenv("TP_DESCRIPTOR_STREAM_ID");
    if (descriptor_stream && descriptor_stream[0] != '\0')
    {
        tp_context_set_descriptor_stream_id(ctx_prod, (int32_t)strtol(descriptor_stream, NULL, 10));
        tp_context_set_descriptor_stream_id(ctx_cons, (int32_t)strtol(descriptor_stream, NULL, 10));
    }
    const char *client_id = getenv("TP_CLIENT_ID");
    uint32_t base_client_id = 0;
    if (client_id && client_id[0] != '\0')
    {
        base_client_id = (uint32_t)strtoul(client_id, NULL, 10);
    }
    if (base_client_id == 0)
    {
        base_client_id = (uint32_t)getpid();
    }
    tp_context_set_client_id(ctx_prod, base_client_id);
    tp_context_set_client_id(ctx_cons, base_client_id + 1);

    if (tp_client_connect(ctx_prod, &client_prod) != TP_OK)
    {
        fprintf(stderr, "client connect failed\n");
        tp_context_close(ctx_prod);
        tp_context_close(ctx_cons);
        return 1;
    }
    if (tp_client_connect(ctx_cons, &client_cons) != TP_OK)
    {
        fprintf(stderr, "client connect failed\n");
        tp_client_close(client_prod);
        tp_context_close(ctx_prod);
        tp_context_close(ctx_cons);
        return 1;
    }

    if (tp_attach_producer(client_prod, stream_id, &producer) != TP_OK)
    {
        tp_client_do_work(client_prod);
        fprintf(stderr, "attach producer failed (code=%d, error=\"%s\")\n",
            client_prod->driver.last_attach.code,
            client_prod->driver.last_attach.error_message);
        fprintf(stderr, "attach response: stream_id=%u epoch=%llu layout=%u header_nslots=%u header_slot_bytes=%u header_uri=\"%s\" pool_count=%u\n",
            client_prod->driver.last_attach.stream_id,
            (unsigned long long)client_prod->driver.last_attach.epoch,
            client_prod->driver.last_attach.layout_version,
            client_prod->driver.last_attach.header_nslots,
            client_prod->driver.last_attach.header_slot_bytes,
            client_prod->driver.last_attach.header_uri,
            client_prod->driver.last_attach.pool_count);
        for (uint32_t i = 0; i < client_prod->driver.last_attach.pool_count; i++)
        {
            fprintf(stderr, "pool[%u]: id=%u nslots=%u stride=%u uri=\"%s\"\n",
                i,
                client_prod->driver.last_attach.pools[i].pool_id,
                client_prod->driver.last_attach.pools[i].nslots,
                client_prod->driver.last_attach.pools[i].stride_bytes,
                client_prod->driver.last_attach.pools[i].uri);
        }
        tp_client_close(client_prod);
        tp_client_close(client_cons);
        tp_context_close(ctx_prod);
        tp_context_close(ctx_cons);
        return 1;
    }
    if (tp_attach_consumer(client_cons, stream_id, &consumer) != TP_OK)
    {
        tp_client_do_work(client_cons);
        fprintf(stderr, "attach consumer failed (code=%d, error=\"%s\")\n",
            client_cons->driver.last_attach.code,
            client_cons->driver.last_attach.error_message);
        fprintf(stderr, "attach response: stream_id=%u epoch=%llu layout=%u header_nslots=%u header_slot_bytes=%u header_uri=\"%s\" pool_count=%u\n",
            client_cons->driver.last_attach.stream_id,
            (unsigned long long)client_cons->driver.last_attach.epoch,
            client_cons->driver.last_attach.layout_version,
            client_cons->driver.last_attach.header_nslots,
            client_cons->driver.last_attach.header_slot_bytes,
            client_cons->driver.last_attach.header_uri,
            client_cons->driver.last_attach.pool_count);
        for (uint32_t i = 0; i < client_cons->driver.last_attach.pool_count; i++)
        {
            fprintf(stderr, "pool[%u]: id=%u nslots=%u stride=%u uri=\"%s\"\n",
                i,
                client_cons->driver.last_attach.pools[i].pool_id,
                client_cons->driver.last_attach.pools[i].nslots,
                client_cons->driver.last_attach.pools[i].stride_bytes,
                client_cons->driver.last_attach.pools[i].uri);
        }
        tp_producer_close(producer);
        tp_client_close(client_prod);
        tp_client_close(client_cons);
        tp_context_close(ctx_prod);
        tp_context_close(ctx_cons);
        return 1;
    }
    const char *debug_env = getenv("TP_DEBUG_INTEGRATION");
    const bool debug = debug_env != NULL && debug_env[0] != '\0';
    if (debug)
    {
        fprintf(stderr, "consumer attach: stream_id=%u epoch=%llu header_uri=\"%s\"\n",
            client_cons->driver.last_attach.stream_id,
            (unsigned long long)client_cons->driver.last_attach.epoch,
            client_cons->driver.last_attach.header_uri);
    }

    if (debug)
    {
        fprintf(stderr, "producer pools: count=%u header_nslots=%u header_slot_bytes=%u\n",
            producer->pool_count,
            producer->header_nslots,
            producer->header_slot_bytes);
        fprintf(stderr, "producer attach: stream_id=%u epoch=%llu header_uri=\"%s\"\n",
            client_prod->driver.last_attach.stream_id,
            (unsigned long long)client_prod->driver.last_attach.epoch,
            client_prod->driver.last_attach.header_uri);
    }
    if (debug)
    {
        for (uint32_t i = 0; i < producer->pool_count; i++)
        {
            fprintf(stderr, "producer pool[%u]: id=%u nslots=%u stride=%u uri=\"%s\"\n",
                i,
                producer->pools[i].pool_id,
                producer->pools[i].nslots,
                producer->pools[i].stride_bytes,
                producer->pools[i].mapping.addr ? "mapped" : "null");
        }
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

    tp_slot_claim_t claim;
    tp_err_t claim_err = tp_producer_try_claim_slot_by_size(producer, (uint32_t)sizeof(payload), &claim);
    if (claim_err != TP_OK)
    {
        fprintf(stderr, "try_claim_slot failed (err=%d)\n", claim_err);
        tp_consumer_close(consumer);
        tp_producer_close(producer);
        tp_client_close(client_prod);
        tp_client_close(client_cons);
        tp_context_close(ctx_prod);
        tp_context_close(ctx_cons);
        return 1;
    }
    memcpy(claim.ptr, payload, sizeof(payload));
    tp_err_t commit_err = tp_producer_commit_slot(producer, &claim, (uint32_t)sizeof(payload), &tensor, 1);
    if (commit_err != TP_OK)
    {
        fprintf(stderr, "commit_slot failed (err=%d)\n", commit_err);
        tp_consumer_close(consumer);
        tp_producer_close(producer);
        tp_client_close(client_prod);
        tp_client_close(client_cons);
        tp_context_close(ctx_prod);
        tp_context_close(ctx_cons);
        return 1;
    }
    uint64_t header_offset = 64 + ((uint64_t)claim.header_index * producer->header_slot_bytes);
    uint32_t header_len_field = *(uint32_t *)(producer->header.addr + header_offset + 60);
    if (debug)
    {
        fprintf(stderr, "producer headerBytes length field=%u\n", header_len_field);
    }

    tp_frame_view_t view;
    uint64_t deadline = now_ns() + 2000000000ULL;
    bool printed_commit = false;
    while (now_ns() < deadline)
    {
        tp_client_do_work(client_prod);
        tp_client_do_work(client_cons);
        tp_consumer_poll(consumer, 10);
        if (debug && consumer->has_descriptor)
        {
            fprintf(stderr, "descriptor seen: seq=%llu header_index=%u\n",
                (unsigned long long)consumer->last_seq,
                consumer->last_header_index);
            if (!printed_commit)
            {
                uint64_t header_offset = 64 + ((uint64_t)consumer->last_header_index * consumer->header_slot_bytes);
                uint64_t commit_word = *(uint64_t *)(consumer->header.addr + header_offset);
                fprintf(stderr, "commit word raw=0x%016llx\n", (unsigned long long)commit_word);
                printed_commit = true;
            }
        }
        tp_err_t read_err = tp_consumer_try_read_frame(consumer, &view);
        if (read_err == TP_OK)
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
            tp_client_close(client_prod);
            tp_client_close(client_cons);
            tp_context_close(ctx_prod);
            tp_context_close(ctx_cons);
            return 0;
        }
        if (read_err != TP_ERR_TIMEOUT)
        {
            if (debug)
            {
                fprintf(stderr, "read frame failed (err=%d)\n", read_err);
            }
            break;
        }
    }

    fprintf(stderr, "timed out waiting for frame\n");
    tp_consumer_close(consumer);
    tp_producer_close(producer);
    tp_client_close(client_prod);
    tp_client_close(client_cons);
    tp_context_close(ctx_prod);
    tp_context_close(ctx_cons);
    return 1;
}
