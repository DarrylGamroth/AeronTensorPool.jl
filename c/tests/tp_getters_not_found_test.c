#include <assert.h>
#include <string.h>

#include "tensorpool_client.h"
#include "tp_internal.h"

int main(void)
{
    tp_qos_monitor_t monitor;
    memset(&monitor, 0, sizeof(monitor));
    tp_qos_producer_snapshot_t prod;
    tp_err_t err = tp_qos_monitor_get_producer(&monitor, 1, &prod);
    assert(err == TP_ERR_NOT_FOUND);

    tp_qos_consumer_snapshot_t cons;
    err = tp_qos_monitor_get_consumer(&monitor, 1, &cons);
    assert(err == TP_ERR_NOT_FOUND);

    tp_metadata_cache_t cache;
    memset(&cache, 0, sizeof(cache));
    tp_metadata_entry_t meta;
    err = tp_metadata_cache_get(&cache, 1, &meta);
    assert(err == TP_ERR_NOT_FOUND);

    tp_discovery_client_t discovery;
    memset(&discovery, 0, sizeof(discovery));
    tp_discovery_entry_t entries[TP_MAX_DISCOVERY_ENTRIES];
    uint32_t entry_count = 0;
    int32_t status = 0;
    err = tp_discovery_get_response(&discovery, 1, entries, &entry_count, NULL, 0, &status);
    assert(err == TP_ERR_NOT_FOUND);

    tp_consumer_t consumer;
    memset(&consumer, 0, sizeof(consumer));
    bool available = true;
    uint64_t frame_id = 0;
    uint64_t bytes = 0;
    uint8_t state = 0;
    err = tp_consumer_get_progress(&consumer, &frame_id, &bytes, &state, &available);
    assert(err == TP_OK);
    assert(!available);

    return 0;
}
