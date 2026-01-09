#ifndef TP_INTERNAL_H
#define TP_INTERNAL_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "tensorpool_errors.h"
#include "tensorpool_types.h"

#include "aeronc.h"
#include "aeron_publication.h"
#include "aeron_subscription.h"
#include "aeron_fragment_assembler.h"

#include "shm_tensorpool_driver/messageHeader.h"
#include "shm_tensorpool_driver/shmAttachRequest.h"
#include "shm_tensorpool_driver/shmAttachResponse.h"
#include "shm_tensorpool_driver/shmDetachRequest.h"
#include "shm_tensorpool_driver/shmDetachResponse.h"
#include "shm_tensorpool_driver/shmLeaseKeepalive.h"
#include "shm_tensorpool_driver/shmLeaseRevoked.h"
#include "shm_tensorpool_driver/shmDriverShutdown.h"

#include "shm_tensorpool_control/messageHeader.h"
#include "shm_tensorpool_control/shmRegionSuperblock.h"
#include "shm_tensorpool_control/slotHeader.h"
#include "shm_tensorpool_control/tensorHeader.h"
#include "shm_tensorpool_control/frameDescriptor.h"
#include "shm_tensorpool_control/frameProgress.h"
#include "shm_tensorpool_control/qosProducer.h"
#include "shm_tensorpool_control/qosConsumer.h"
#include "shm_tensorpool_control/dataSourceAnnounce.h"
#include "shm_tensorpool_control/dataSourceMeta.h"
#include "shm_tensorpool_control/shmPoolAnnounce.h"
#include "shm_tensorpool_control/consumerHello.h"
#include "shm_tensorpool_control/consumerConfig.h"

#include "shm_tensorpool_discovery/messageHeader.h"
#include "shm_tensorpool_discovery/discoveryRequest.h"
#include "shm_tensorpool_discovery/discoveryResponse.h"
#include "shm_tensorpool_discovery/discoveryStatus.h"

#define TP_SUPERBLOCK_SIZE 64
#define TP_HEADER_SLOT_BYTES 256

typedef struct tp_context_stct
{
    uint64_t attach_timeout_ns;
    uint64_t detach_timeout_ns;
    uint64_t qos_interval_ns;
    uint64_t lease_keepalive_interval_ns;
    uint64_t announce_freshness_ns;
    uint64_t consumer_max_rate_hz;
    uint32_t client_id;
    int32_t control_stream_id;
    int32_t descriptor_stream_id;
    int32_t qos_stream_id;
    int32_t consumer_descriptor_stream_id;
    int32_t consumer_control_stream_id;
    uint8_t consumer_mode;
    bool use_invoker;
    char aeron_dir[TP_URI_MAX];
    char control_channel[TP_URI_MAX];
    char descriptor_channel[TP_URI_MAX];
    char qos_channel[TP_URI_MAX];
    char consumer_descriptor_channel[TP_URI_MAX];
    char consumer_control_channel[TP_URI_MAX];
}
tp_context_t;

typedef struct tp_driver_client_stct
{
    aeron_publication_t *pub;
    aeron_subscription_t *sub;
    aeron_fragment_assembler_t *assembler;
    tp_attach_response_t last_attach;
    uint64_t pending_detach_lease_id;
    uint64_t last_detach_lease_id;
    uint64_t revoked_lease_id;
    int64_t last_attach_correlation;
    int64_t pending_attach_correlation;
    int64_t last_detach_correlation;
    int64_t pending_detach_correlation;
    uint32_t pending_detach_stream_id;
    uint32_t last_detach_stream_id;
    uint32_t revoked_stream_id;
    int32_t last_detach_code;
    uint8_t pending_detach_role;
    uint8_t last_detach_role;
    uint8_t revoked_role;
    uint8_t revoked_reason;
    uint8_t shutdown_reason;
    bool last_attach_valid;
    bool shutdown;
}
tp_driver_client_t;

typedef struct tp_client_stct
{
    tp_context_t *context;
    aeron_context_t *aeron_ctx;
    aeron_t *aeron;
    tp_driver_client_t driver;
    int64_t next_correlation_id;
}
tp_client_t;

typedef struct tp_qos_monitor_stct
{
    tp_client_t *client;
    aeron_subscription_t *sub;
    aeron_fragment_assembler_t *assembler;
    uint32_t producer_count;
    uint32_t consumer_count;
    tp_qos_producer_snapshot_t producers[TP_MAX_QOS_ENTRIES];
    tp_qos_consumer_snapshot_t consumers[TP_MAX_QOS_ENTRIES];
}
tp_qos_monitor_t;

typedef struct tp_metadata_cache_stct
{
    tp_client_t *client;
    aeron_subscription_t *sub;
    aeron_fragment_assembler_t *assembler;
    uint32_t entry_count;
    tp_metadata_entry_t entries[TP_MAX_METADATA_ENTRIES];
}
tp_metadata_cache_t;

typedef struct tp_discovery_client_stct
{
    tp_client_t *client;
    aeron_publication_t *pub;
    aeron_subscription_t *sub;
    aeron_fragment_assembler_t *assembler;
    uint64_t next_request_id;
    uint64_t last_request_id;
    int32_t last_status;
    int32_t response_stream_id;
    uint32_t entry_count;
    char response_channel[TP_URI_MAX];
    char last_error[TP_URI_MAX];
    tp_discovery_entry_t entries[TP_MAX_DISCOVERY_ENTRIES];
}
tp_discovery_client_t;

typedef struct tp_shm_mapping_stct
{
    uint8_t *addr;
    size_t length;
}
tp_shm_mapping_t;

typedef struct tp_pool_mapping_stct
{
    uint16_t pool_id;
    uint32_t nslots;
    uint32_t stride_bytes;
    tp_shm_mapping_t mapping;
}
tp_pool_mapping_t;

typedef struct tp_producer_stct
{
    tp_client_t *client;
    aeron_publication_t *pub_descriptor;
    aeron_publication_t *pub_qos;
    uint64_t lease_id;
    uint64_t epoch;
    uint64_t seq;
    uint64_t last_qos_ns;
    uint64_t last_keepalive_ns;
    uint32_t stream_id;
    uint32_t layout_version;
    uint32_t header_nslots;
    uint32_t pool_count;
    uint16_t header_slot_bytes;
    bool revoked;
    tp_shm_mapping_t header;
    tp_pool_mapping_t pools[TP_MAX_POOLS];
}
tp_producer_t;

typedef struct tp_consumer_stct
{
    tp_client_t *client;
    aeron_subscription_t *sub_descriptor;
    aeron_fragment_assembler_t *descriptor_assembler;
    aeron_publication_t *pub_control;
    aeron_subscription_t *sub_control;
    aeron_fragment_assembler_t *control_assembler;
    aeron_publication_t *pub_qos;
    uint64_t last_progress_frame_id;
    uint64_t last_progress_bytes;
    uint64_t last_qos_ns;
    uint64_t last_keepalive_ns;
    uint64_t drops_gap;
    uint64_t drops_late;
    uint64_t lease_id;
    uint64_t epoch;
    uint64_t join_time_ns;
    uint64_t last_announce_timestamp_ns;
    uint64_t last_seq;
    uint64_t last_epoch;
    uint32_t stream_id;
    uint32_t layout_version;
    uint32_t header_nslots;
    uint32_t pool_count;
    uint32_t last_header_index;
    uint32_t last_meta_version;
    uint32_t last_progress_header_index;
    int32_t descriptor_stream_id;
    int32_t control_stream_id;
    uint16_t header_slot_bytes;
    uint8_t last_announce_clock_domain;
    uint8_t last_progress_state;
    bool has_descriptor;
    bool revoked;
    bool has_progress;
    char descriptor_channel[TP_URI_MAX];
    char control_channel[TP_URI_MAX];
    tp_shm_mapping_t header;
    tp_pool_mapping_t pools[TP_MAX_POOLS];
}
tp_consumer_t;

tp_err_t tp_driver_client_init(tp_client_t *client);
void tp_driver_client_close(tp_driver_client_t *driver);
int tp_driver_poll(tp_client_t *client, int fragment_limit);
int tp_client_do_work(tp_client_t *client);
void tp_client_close(tp_client_t *client);
void tp_producer_close(tp_producer_t *producer);
void tp_consumer_close(tp_consumer_t *consumer);
void tp_consumer_handle_control_buffer(tp_consumer_t *consumer, const uint8_t *buffer, size_t length);
int tp_add_publication(aeron_t *client, const char *channel, int32_t stream_id, aeron_publication_t **pub);
int tp_add_subscription(aeron_t *client, const char *channel, int32_t stream_id, aeron_subscription_t **sub);
tp_err_t tp_send_attach_request(tp_client_t *client, uint32_t stream_id, uint8_t role, uint8_t publish_mode);
tp_err_t tp_wait_attach(tp_client_t *client, int64_t correlation_id, tp_attach_response_t *out);
tp_err_t tp_validate_attach_response(const tp_attach_response_t *resp);
tp_err_t tp_lease_keepalive(tp_client_t *client, uint64_t lease_id, uint32_t stream_id, uint32_t client_id, uint8_t role);

tp_err_t tp_shm_map(const char *uri, size_t size, bool write, tp_shm_mapping_t *mapping);
void tp_shm_unmap(tp_shm_mapping_t *mapping);
tp_err_t tp_shm_validate_uri(const char *uri, bool *require_hugepages);
tp_err_t tp_validate_stride_bytes(uint32_t stride_bytes, bool require_hugepages);
tp_err_t tp_shm_validate_superblock(
    const tp_shm_mapping_t *mapping,
    uint32_t expected_layout_version,
    uint64_t expected_epoch,
    uint32_t expected_stream_id,
    uint32_t expected_nslots,
    uint32_t expected_slot_bytes,
    uint32_t expected_stride_bytes,
    uint16_t expected_pool_id,
    uint16_t expected_region_type);

uint64_t tp_now_ns(void);
uint64_t tp_now_realtime_ns(void);

void tp_qos_monitor_handle_buffer(tp_qos_monitor_t *monitor, char *buffer, size_t length);
void tp_metadata_cache_handle_buffer(tp_metadata_cache_t *cache, char *buffer, size_t length);
void tp_discovery_client_handle_buffer(tp_discovery_client_t *client, char *buffer, size_t length);

#endif
