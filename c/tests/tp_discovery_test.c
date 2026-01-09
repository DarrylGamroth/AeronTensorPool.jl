#include <assert.h>
#include <string.h>

#include "tp_internal.h"

static size_t tp_discovery_response_length(const struct shm_tensorpool_discovery_discoveryResponse *msg)
{
    return shm_tensorpool_discovery_messageHeader_encoded_length() +
        shm_tensorpool_discovery_discoveryResponse_encoded_length(msg);
}

int main(void)
{
    tp_discovery_client_t client;
    memset(&client, 0, sizeof(client));

    char buffer[2048];
    memset(buffer, 0, sizeof(buffer));

    struct shm_tensorpool_discovery_discoveryResponse resp;
    struct shm_tensorpool_discovery_messageHeader header;
    shm_tensorpool_discovery_discoveryResponse_wrap_and_apply_header(&resp, buffer, 0, sizeof(buffer), &header);
    shm_tensorpool_discovery_discoveryResponse_set_requestId(&resp, 1);
    shm_tensorpool_discovery_discoveryResponse_set_status(&resp, shm_tensorpool_discovery_discoveryStatus_OK);

    struct shm_tensorpool_discovery_discoveryResponse_results results;
    shm_tensorpool_discovery_discoveryResponse_results_set_count(&resp, &results, 1);
    shm_tensorpool_discovery_discoveryResponse_results_next(&results);
    shm_tensorpool_discovery_discoveryResponse_results_set_streamId(&results, 10000);
    shm_tensorpool_discovery_discoveryResponse_results_set_producerId(&results, 55);
    shm_tensorpool_discovery_discoveryResponse_results_set_epoch(&results, 9);
    shm_tensorpool_discovery_discoveryResponse_results_set_layoutVersion(&results, 1);
    shm_tensorpool_discovery_discoveryResponse_results_set_headerNslots(&results, 128);
    shm_tensorpool_discovery_discoveryResponse_results_set_headerSlotBytes(&results, 256);
    shm_tensorpool_discovery_discoveryResponse_results_set_maxDims(&results, 8);
    shm_tensorpool_discovery_discoveryResponse_results_set_dataSourceId(&results, 77);
    shm_tensorpool_discovery_discoveryResponse_results_set_driverControlStreamId(&results, 10001);
    const char *header_uri = "shm:file?path=/dev/shm/tp_header";
    const char *data_name = "camera";
    const char *driver_id = "driver-1";
    const char *driver_channel = "aeron:ipc";
    shm_tensorpool_discovery_discoveryResponse_results_put_headerRegionUri(
        &results,
        header_uri,
        (uint32_t)strlen(header_uri));
    shm_tensorpool_discovery_discoveryResponse_results_put_dataSourceName(
        &results,
        data_name,
        (uint32_t)strlen(data_name));
    shm_tensorpool_discovery_discoveryResponse_results_put_driverInstanceId(
        &results,
        driver_id,
        (uint32_t)strlen(driver_id));
    shm_tensorpool_discovery_discoveryResponse_results_put_driverControlChannel(
        &results,
        driver_channel,
        (uint32_t)strlen(driver_channel));

    struct shm_tensorpool_discovery_discoveryResponse_results_payloadPools pools;
    shm_tensorpool_discovery_discoveryResponse_results_payloadPools_set_count(&results, &pools, 1);
    shm_tensorpool_discovery_discoveryResponse_results_payloadPools_next(&pools);
    shm_tensorpool_discovery_discoveryResponse_results_payloadPools_set_poolId(&pools, 1);
    shm_tensorpool_discovery_discoveryResponse_results_payloadPools_set_poolNslots(&pools, 128);
    shm_tensorpool_discovery_discoveryResponse_results_payloadPools_set_strideBytes(&pools, 1024);
    const char *pool_uri = "shm:file?path=/dev/shm/tp_pool";
    shm_tensorpool_discovery_discoveryResponse_results_payloadPools_put_regionUri(
        &pools,
        pool_uri,
        (uint32_t)strlen(pool_uri));

    struct shm_tensorpool_discovery_discoveryResponse_results_tags tags;
    shm_tensorpool_discovery_discoveryResponse_results_tags_set_count(&results, &tags, 1);
    shm_tensorpool_discovery_discoveryResponse_results_tags_next(&tags);
    struct shm_tensorpool_discovery_varAsciiEncoding tag_var;
    shm_tensorpool_discovery_discoveryResponse_results_tags_tag(&tags, &tag_var);
    shm_tensorpool_discovery_varAsciiEncoding_set_length(&tag_var, 4);
    memcpy(
        shm_tensorpool_discovery_varAsciiEncoding_mut_buffer(&tag_var) +
            shm_tensorpool_discovery_varAsciiEncoding_offset(&tag_var) +
            shm_tensorpool_discovery_varAsciiEncoding_varData_encoding_offset(),
        "rgb8",
        4);

    tp_discovery_client_handle_buffer(&client, buffer, tp_discovery_response_length(&resp));

    assert(client.last_request_id == 1);
    assert(client.last_status == (int32_t)shm_tensorpool_discovery_discoveryStatus_OK);
    assert(client.entry_count == 1);
    assert(client.entries[0].stream_id == 10000);
    assert(client.entries[0].producer_id == 55);
    assert(client.entries[0].epoch == 9);
    assert(client.entries[0].layout_version == 1);
    assert(client.entries[0].header_nslots == 128);
    assert(client.entries[0].header_slot_bytes == 256);
    assert(client.entries[0].max_dims == 8);
    assert(client.entries[0].data_source_id == 77);
    assert(client.entries[0].driver_control_stream_id == 10001);
    assert(strcmp(client.entries[0].header_region_uri, "shm:file?path=/dev/shm/tp_header") == 0);
    assert(strcmp(client.entries[0].data_source_name, "camera") == 0);
    assert(strcmp(client.entries[0].driver_instance_id, "driver-1") == 0);
    assert(strcmp(client.entries[0].driver_control_channel, "aeron:ipc") == 0);
    assert(client.entries[0].pool_count == 1);
    assert(client.entries[0].pools[0].pool_id == 1);
    assert(client.entries[0].pools[0].pool_nslots == 128);
    assert(client.entries[0].pools[0].stride_bytes == 1024);
    assert(strcmp(client.entries[0].pools[0].region_uri, "shm:file?path=/dev/shm/tp_pool") == 0);
    assert(client.entries[0].tag_count == 1);
    assert(strcmp(client.entries[0].tags[0], "rgb8") == 0);

    memset(buffer, 0, sizeof(buffer));
    shm_tensorpool_discovery_discoveryResponse_wrap_and_apply_header(&resp, buffer, 0, sizeof(buffer), &header);
    shm_tensorpool_discovery_discoveryResponse_set_requestId(&resp, 2);
    shm_tensorpool_discovery_discoveryResponse_set_status(&resp, shm_tensorpool_discovery_discoveryStatus_ERROR);
    shm_tensorpool_discovery_discoveryResponse_put_errorMessage(&resp, "failed", 6);
    tp_discovery_client_handle_buffer(&client, buffer, tp_discovery_response_length(&resp));

    assert(client.last_request_id == 2);
    assert(client.last_status == (int32_t)shm_tensorpool_discovery_discoveryStatus_ERROR);
    assert(strcmp(client.last_error, "failed") == 0);

    return 0;
}
