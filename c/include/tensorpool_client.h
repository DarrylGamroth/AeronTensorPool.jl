#ifndef TENSORPOOL_CLIENT_H
#define TENSORPOOL_CLIENT_H

#include <stdint.h>
#include <stdbool.h>
#include "tensorpool_errors.h"
#include "tensorpool_types.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct tp_context_stct tp_context_t;
typedef struct tp_client_stct tp_client_t;
typedef struct tp_producer_stct tp_producer_t;
typedef struct tp_consumer_stct tp_consumer_t;
typedef struct tp_qos_monitor_stct tp_qos_monitor_t;
typedef struct tp_metadata_cache_stct tp_metadata_cache_t;
typedef struct tp_discovery_client_stct tp_discovery_client_t;

tp_err_t tp_context_init(tp_context_t **ctx);
void tp_context_close(tp_context_t *ctx);

tp_err_t tp_context_set_aeron_dir(tp_context_t *ctx, const char *aeron_dir);
tp_err_t tp_context_set_control_channel(tp_context_t *ctx, const char *channel);
tp_err_t tp_context_set_control_stream_id(tp_context_t *ctx, int32_t stream_id);
tp_err_t tp_context_set_descriptor_channel(tp_context_t *ctx, const char *channel);
tp_err_t tp_context_set_descriptor_stream_id(tp_context_t *ctx, int32_t stream_id);
tp_err_t tp_context_set_qos_channel(tp_context_t *ctx, const char *channel);
tp_err_t tp_context_set_qos_stream_id(tp_context_t *ctx, int32_t stream_id);
tp_err_t tp_context_set_metadata_channel(tp_context_t *ctx, const char *channel);
tp_err_t tp_context_set_metadata_stream_id(tp_context_t *ctx, int32_t stream_id);
tp_err_t tp_context_set_client_id(tp_context_t *ctx, uint32_t client_id);
tp_err_t tp_context_set_use_invoker(tp_context_t *ctx, bool value);
tp_err_t tp_context_set_attach_timeout_ns(tp_context_t *ctx, uint64_t timeout_ns);
tp_err_t tp_context_set_qos_interval_ns(tp_context_t *ctx, uint64_t interval_ns);
tp_err_t tp_context_set_detach_timeout_ns(tp_context_t *ctx, uint64_t timeout_ns);
tp_err_t tp_context_set_announce_freshness_ns(tp_context_t *ctx, uint64_t freshness_ns);
tp_err_t tp_context_set_lease_keepalive_interval_ns(tp_context_t *ctx, uint64_t interval_ns);
tp_err_t tp_context_set_consumer_mode(tp_context_t *ctx, uint8_t mode);
tp_err_t tp_context_set_consumer_max_rate_hz(tp_context_t *ctx, uint64_t rate_hz);
tp_err_t tp_context_set_consumer_descriptor_request(tp_context_t *ctx, const char *channel, int32_t stream_id);
tp_err_t tp_context_set_consumer_control_request(tp_context_t *ctx, const char *channel, int32_t stream_id);

tp_err_t tp_client_connect(tp_context_t *ctx, tp_client_t **client);
void tp_client_close(tp_client_t *client);
int tp_client_do_work(tp_client_t *client);

tp_err_t tp_attach_producer(tp_client_t *client, uint32_t stream_id, tp_producer_t **producer);
tp_err_t tp_attach_consumer(tp_client_t *client, uint32_t stream_id, tp_consumer_t **consumer);
tp_err_t tp_producer_reattach(tp_producer_t **producer);
tp_err_t tp_consumer_reattach(tp_consumer_t **consumer);

tp_err_t tp_detach(tp_client_t *client, uint64_t lease_id, uint32_t stream_id, uint32_t client_id, uint8_t role);
tp_err_t tp_lease_keepalive(tp_client_t *client, uint64_t lease_id, uint32_t stream_id, uint32_t client_id, uint8_t role);

tp_err_t tp_producer_offer_frame(
    tp_producer_t *producer,
    const uint8_t *payload,
    uint32_t values_len,
    const tp_tensor_header_t *tensor,
    uint32_t meta_version);

tp_err_t tp_producer_try_claim_slot(tp_producer_t *producer, uint16_t pool_id, tp_slot_claim_t *claim);
tp_err_t tp_producer_try_claim_slot_by_size(tp_producer_t *producer, uint32_t values_len, tp_slot_claim_t *claim);
tp_err_t tp_producer_commit_slot(
    tp_producer_t *producer,
    tp_slot_claim_t *claim,
    uint32_t values_len,
    const tp_tensor_header_t *tensor,
    uint32_t meta_version);

tp_err_t tp_producer_metadata_version(const tp_producer_t *producer, uint32_t *meta_version);
tp_err_t tp_producer_set_metadata(
    tp_producer_t *producer,
    const char *name,
    const char *summary,
    const tp_metadata_attribute_t *attrs,
    uint32_t attr_count);
tp_err_t tp_producer_announce_data_source(tp_producer_t *producer, const char *name, const char *summary);
tp_err_t tp_producer_set_metadata_attributes(
    tp_producer_t *producer,
    const tp_metadata_attribute_t *attrs,
    uint32_t attr_count);
tp_err_t tp_producer_set_metadata_attribute(
    tp_producer_t *producer,
    const char *key,
    const char *mime_type,
    const uint8_t *value,
    uint32_t value_len);
tp_err_t tp_producer_delete_metadata_attribute(tp_producer_t *producer, const char *key);

tp_err_t tp_producer_send_metadata_announce(
    tp_producer_t *producer,
    uint32_t meta_version,
    const char *name,
    const char *summary);
tp_err_t tp_producer_send_metadata_meta(
    tp_producer_t *producer,
    uint32_t meta_version,
    uint64_t timestamp_ns,
    const tp_metadata_attribute_t *attrs,
    uint32_t attr_count);
tp_err_t tp_producer_send_qos(tp_producer_t *producer, uint64_t current_seq, uint64_t watermark);
tp_err_t tp_producer_poll(tp_producer_t *producer);
tp_err_t tp_producer_get_lease_id(const tp_producer_t *producer, uint64_t *lease_id);
tp_err_t tp_producer_get_stream_id(const tp_producer_t *producer, uint32_t *stream_id);
tp_err_t tp_producer_get_producer_id(const tp_producer_t *producer, uint32_t *producer_id);

tp_err_t tp_consumer_poll(tp_consumer_t *consumer, int fragment_limit);
tp_err_t tp_consumer_try_read_frame(tp_consumer_t *consumer, tp_frame_view_t *view);
tp_err_t tp_consumer_send_qos(
    tp_consumer_t *consumer,
    uint8_t mode,
    uint64_t last_seq_seen,
    uint64_t drops_gap,
    uint64_t drops_late);
tp_err_t tp_consumer_get_progress(
    const tp_consumer_t *consumer,
    uint64_t *frame_id,
    uint64_t *bytes_filled,
    uint8_t *state,
    bool *available);
tp_err_t tp_consumer_get_lease_id(const tp_consumer_t *consumer, uint64_t *lease_id);
tp_err_t tp_consumer_get_stream_id(const tp_consumer_t *consumer, uint32_t *stream_id);
tp_err_t tp_consumer_get_consumer_id(const tp_consumer_t *consumer, uint32_t *consumer_id);
tp_err_t tp_client_get_client_id(const tp_client_t *client, uint32_t *client_id);

const char *tp_err_str(tp_err_t err);

void tp_producer_close(tp_producer_t *producer);
void tp_consumer_close(tp_consumer_t *consumer);

bool tp_producer_is_connected(const tp_producer_t *producer);
bool tp_consumer_is_connected(const tp_consumer_t *consumer);

tp_err_t tp_qos_monitor_init(tp_client_t *client, const char *channel, int32_t stream_id, tp_qos_monitor_t **monitor);
void tp_qos_monitor_close(tp_qos_monitor_t *monitor);
int tp_qos_monitor_poll(tp_qos_monitor_t *monitor, int fragment_limit);
tp_err_t tp_qos_monitor_get_producer(
    const tp_qos_monitor_t *monitor,
    uint32_t producer_id,
    tp_qos_producer_snapshot_t *out);
tp_err_t tp_qos_monitor_get_consumer(
    const tp_qos_monitor_t *monitor,
    uint32_t consumer_id,
    tp_qos_consumer_snapshot_t *out);

tp_err_t tp_metadata_cache_init(tp_client_t *client, const char *channel, int32_t stream_id, tp_metadata_cache_t **cache);
void tp_metadata_cache_close(tp_metadata_cache_t *cache);
int tp_metadata_cache_poll(tp_metadata_cache_t *cache, int fragment_limit);
tp_err_t tp_metadata_cache_get(const tp_metadata_cache_t *cache, uint32_t stream_id, tp_metadata_entry_t *out);

tp_err_t tp_discovery_client_init(
    tp_client_t *client,
    const char *request_channel,
    int32_t request_stream_id,
    const char *response_channel,
    int32_t response_stream_id,
    tp_discovery_client_t **discovery);
void tp_discovery_client_close(tp_discovery_client_t *discovery);
int tp_discovery_client_poll(tp_discovery_client_t *discovery, int fragment_limit);
tp_err_t tp_discovery_send_request(
    tp_discovery_client_t *discovery,
    uint32_t stream_id,
    uint32_t producer_id,
    uint32_t data_source_id,
    const char *data_source_name,
    const char **tags,
    uint32_t tag_count,
    uint64_t *request_id);
tp_err_t tp_discovery_get_response(
    const tp_discovery_client_t *discovery,
    uint64_t request_id,
    tp_discovery_entry_t *entries,
    uint32_t *entry_count,
    char *error_message,
    size_t error_len,
    int32_t *status);

#ifdef __cplusplus
}
#endif

#endif
