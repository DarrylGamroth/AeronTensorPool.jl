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

tp_err_t tp_context_init(tp_context_t **ctx);
void tp_context_close(tp_context_t *ctx);

tp_err_t tp_context_set_aeron_dir(tp_context_t *ctx, const char *aeron_dir);
tp_err_t tp_context_set_control_channel(tp_context_t *ctx, const char *channel);
tp_err_t tp_context_set_control_stream_id(tp_context_t *ctx, int32_t stream_id);
tp_err_t tp_context_set_descriptor_channel(tp_context_t *ctx, const char *channel);
tp_err_t tp_context_set_descriptor_stream_id(tp_context_t *ctx, int32_t stream_id);
tp_err_t tp_context_set_client_id(tp_context_t *ctx, uint32_t client_id);
tp_err_t tp_context_set_use_invoker(tp_context_t *ctx, bool value);
tp_err_t tp_context_set_attach_timeout_ns(tp_context_t *ctx, uint64_t timeout_ns);

tp_err_t tp_client_connect(tp_context_t *ctx, tp_client_t **client);
void tp_client_close(tp_client_t *client);
int tp_client_do_work(tp_client_t *client);

tp_err_t tp_attach_producer(tp_client_t *client, uint32_t stream_id, tp_producer_t **producer);
tp_err_t tp_attach_consumer(tp_client_t *client, uint32_t stream_id, tp_consumer_t **consumer);

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

tp_err_t tp_consumer_poll(tp_consumer_t *consumer, int fragment_limit);
tp_err_t tp_consumer_try_read_frame(tp_consumer_t *consumer, tp_frame_view_t *view);

void tp_producer_close(tp_producer_t *producer);
void tp_consumer_close(tp_consumer_t *consumer);

bool tp_producer_is_connected(tp_producer_t *producer);
bool tp_consumer_is_connected(tp_consumer_t *consumer);

#ifdef __cplusplus
}
#endif

#endif
