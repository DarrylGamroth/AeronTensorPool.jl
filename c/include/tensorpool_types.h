#ifndef TENSORPOOL_TYPES_H
#define TENSORPOOL_TYPES_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TP_MAX_POOLS 16
#define TP_URI_MAX 1024
#define TP_MAX_DIMS 8
#define TP_MAX_QOS_ENTRIES 64
#define TP_MAX_METADATA_ENTRIES 64
#define TP_MAX_METADATA_ATTRS 32
#define TP_METADATA_TEXT_MAX 256
#define TP_METADATA_VALUE_MAX 512
#define TP_MAX_DISCOVERY_ENTRIES 64
#define TP_MAX_TAGS 16
#define TP_TAG_MAX 64

typedef struct tp_pool_desc_stct
{
    uint16_t pool_id;
    uint32_t nslots;
    uint32_t stride_bytes;
    char uri[TP_URI_MAX];
}
tp_pool_desc_t;

typedef struct tp_attach_response_stct
{
    int64_t correlation_id;
    int32_t code;
    uint64_t lease_id;
    uint32_t stream_id;
    uint64_t epoch;
    uint32_t layout_version;
    uint32_t header_nslots;
    uint16_t header_slot_bytes;
    uint8_t max_dims;
    uint64_t lease_expiry_ns;
    char header_uri[TP_URI_MAX];
    char error_message[TP_URI_MAX];
    uint32_t pool_count;
    tp_pool_desc_t pools[TP_MAX_POOLS];
}
tp_attach_response_t;

typedef struct tp_slot_claim_stct
{
    uint64_t seq;
    uint8_t *ptr;
    uint32_t stride_bytes;
    uint32_t header_index;
    uint32_t payload_slot;
    uint16_t pool_id;
}
tp_slot_claim_t;

typedef struct tp_tensor_header_stct
{
    uint8_t dtype;
    uint8_t major_order;
    uint8_t ndims;
    uint8_t pad_align;
    uint8_t progress_unit;
    uint32_t progress_stride_bytes;
    int32_t dims[TP_MAX_DIMS];
    int32_t strides[TP_MAX_DIMS];
}
tp_tensor_header_t;

typedef struct tp_frame_view_stct
{
    uint64_t seq_commit;
    uint64_t timestamp_ns;
    uint32_t values_len_bytes;
    uint32_t payload_slot;
    uint16_t pool_id;
    uint32_t payload_offset;
    uint32_t meta_version;
    tp_tensor_header_t tensor;
    uint8_t *payload;
    uint32_t payload_len;
}
tp_frame_view_t;

typedef struct tp_qos_producer_snapshot_stct
{
    uint32_t stream_id;
    uint32_t producer_id;
    uint64_t epoch;
    uint64_t current_seq;
    uint64_t watermark;
}
tp_qos_producer_snapshot_t;

typedef struct tp_qos_consumer_snapshot_stct
{
    uint32_t stream_id;
    uint32_t consumer_id;
    uint64_t epoch;
    uint8_t mode;
    uint64_t last_seq_seen;
    uint64_t drops_gap;
    uint64_t drops_late;
}
tp_qos_consumer_snapshot_t;

typedef struct tp_metadata_attribute_stct
{
    char key[TP_METADATA_TEXT_MAX];
    char mime_type[TP_METADATA_TEXT_MAX];
    uint8_t value[TP_METADATA_VALUE_MAX];
    uint32_t value_len;
}
tp_metadata_attribute_t;

typedef struct tp_metadata_entry_stct
{
    uint32_t stream_id;
    uint32_t producer_id;
    uint64_t epoch;
    uint32_t meta_version;
    uint64_t timestamp_ns;
    char name[TP_METADATA_TEXT_MAX];
    char summary[TP_METADATA_TEXT_MAX];
    uint32_t attr_count;
    tp_metadata_attribute_t attrs[TP_MAX_METADATA_ATTRS];
}
tp_metadata_entry_t;

typedef struct tp_discovery_pool_entry_stct
{
    uint16_t pool_id;
    uint32_t pool_nslots;
    uint32_t stride_bytes;
    char region_uri[TP_URI_MAX];
}
tp_discovery_pool_entry_t;

typedef struct tp_discovery_entry_stct
{
    uint32_t stream_id;
    uint32_t producer_id;
    uint64_t epoch;
    uint32_t layout_version;
    uint32_t header_nslots;
    uint16_t header_slot_bytes;
    uint8_t max_dims;
    uint32_t data_source_id;
    uint32_t driver_control_stream_id;
    char header_region_uri[TP_URI_MAX];
    char data_source_name[TP_METADATA_TEXT_MAX];
    char driver_instance_id[TP_METADATA_TEXT_MAX];
    char driver_control_channel[TP_URI_MAX];
    uint32_t pool_count;
    tp_discovery_pool_entry_t pools[TP_MAX_POOLS];
    uint32_t tag_count;
    char tags[TP_MAX_TAGS][TP_TAG_MAX];
}
tp_discovery_entry_t;

#ifdef __cplusplus
}
#endif

#endif
