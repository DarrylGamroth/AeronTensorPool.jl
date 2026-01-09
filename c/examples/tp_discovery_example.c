#include <stdbool.h>
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

static uint32_t split_tags(char *text, const char **out_tags, uint32_t max_tags)
{
    uint32_t count = 0;
    char *cursor = text;
    while (cursor != NULL && *cursor != '\0' && count < max_tags)
    {
        char *comma = strchr(cursor, ',');
        if (comma != NULL)
        {
            *comma = '\0';
        }
        if (*cursor != '\0')
        {
            out_tags[count++] = cursor;
        }
        if (comma == NULL)
        {
            break;
        }
        cursor = comma + 1;
    }
    return count;
}

int main(int argc, char **argv)
{
    (void)argc;
    (void)argv;

    const char *env = getenv("TP_STREAM_ID");
    uint32_t stream_id = env ? (uint32_t)strtoul(env, NULL, 10) : 0;
    env = getenv("TP_DISCOVERY_PRODUCER_ID");
    uint32_t producer_id = env ? (uint32_t)strtoul(env, NULL, 10) : 0;
    env = getenv("TP_DISCOVERY_DATA_SOURCE_ID");
    uint32_t data_source_id = env ? (uint32_t)strtoul(env, NULL, 10) : 0;
    const char *data_source_name = getenv("TP_DISCOVERY_DATA_SOURCE_NAME");
    const char *request_channel = getenv("TP_DISCOVERY_REQUEST_CHANNEL");
    const char *response_channel = getenv("TP_DISCOVERY_RESPONSE_CHANNEL");
    env = getenv("TP_DISCOVERY_REQUEST_STREAM_ID");
    int32_t request_stream_id = env ? (int32_t)strtoul(env, NULL, 10) : 0;
    env = getenv("TP_DISCOVERY_RESPONSE_STREAM_ID");
    int32_t response_stream_id = env ? (int32_t)strtoul(env, NULL, 10) : 0;
    env = getenv("TP_DISCOVERY_TIMEOUT_MS");
    uint64_t timeout_ns = env ? (uint64_t)strtoull(env, NULL, 10) * 1000000ULL : 5000000000ULL;

    if (request_channel == NULL || response_channel == NULL ||
        request_stream_id == 0 || response_stream_id == 0)
    {
        fprintf(stderr, "set TP_DISCOVERY_REQUEST_CHANNEL/STREAM_ID and TP_DISCOVERY_RESPONSE_CHANNEL/STREAM_ID\n");
        return 1;
    }

    tp_context_t *ctx = NULL;
    tp_client_t *client = NULL;
    tp_discovery_client_t *discovery = NULL;

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
    if (tp_discovery_client_init(
            client,
            request_channel,
            request_stream_id,
            response_channel,
            response_stream_id,
            &discovery) != TP_OK)
    {
        fprintf(stderr, "discovery init failed\n");
        tp_client_close(client);
        tp_context_close(ctx);
        return 1;
    }

    const char *tags_env = getenv("TP_DISCOVERY_TAGS");
    const char *tags[TP_MAX_TAGS];
    char tags_buf[TP_TAG_MAX * TP_MAX_TAGS];
    uint32_t tag_count = 0;
    if (tags_env && tags_env[0] != '\0')
    {
        snprintf(tags_buf, sizeof(tags_buf), "%s", tags_env);
        tag_count = split_tags(tags_buf, tags, TP_MAX_TAGS);
    }

    uint64_t request_id = 0;
    tp_err_t req_err = tp_discovery_send_request(
        discovery,
        stream_id,
        producer_id,
        data_source_id,
        data_source_name,
        tags,
        tag_count,
        &request_id);
    if (req_err != TP_OK)
    {
        fprintf(stderr, "discovery request failed (err=%d)\n", req_err);
        tp_discovery_client_close(discovery);
        tp_client_close(client);
        tp_context_close(ctx);
        return 1;
    }

    uint64_t deadline = now_ns() + timeout_ns;
    tp_discovery_entry_t entries[TP_MAX_DISCOVERY_ENTRIES];
    uint32_t entry_count = TP_MAX_DISCOVERY_ENTRIES;
    char error_message[TP_URI_MAX];
    int32_t status = 0;
    while (now_ns() < deadline)
    {
        tp_client_do_work(client);
        tp_discovery_client_poll(discovery, 10);
        tp_err_t resp_err = tp_discovery_get_response(
            discovery,
            request_id,
            entries,
            &entry_count,
            error_message,
            sizeof(error_message),
            &status);
        if (resp_err == TP_OK)
        {
            printf("discovery status=%d entries=%u\n", status, entry_count);
            for (uint32_t i = 0; i < entry_count; i++)
            {
                printf("stream=%u producer=%u epoch=%llu pools=%u header_uri=%s\n",
                    entries[i].stream_id,
                    entries[i].producer_id,
                    (unsigned long long)entries[i].epoch,
                    entries[i].pool_count,
                    entries[i].header_region_uri);
            }
            break;
        }
        if (resp_err != TP_ERR_TIMEOUT)
        {
            fprintf(stderr, "discovery response failed (err=%d)\n", resp_err);
            break;
        }
    }

    tp_discovery_client_close(discovery);
    tp_client_close(client);
    tp_context_close(ctx);
    return 0;
}
