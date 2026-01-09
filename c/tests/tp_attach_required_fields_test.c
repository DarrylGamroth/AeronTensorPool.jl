#include <assert.h>
#include <string.h>

#include "tp_internal.h"

static tp_attach_response_t make_valid_resp(void)
{
    tp_attach_response_t resp;
    memset(&resp, 0, sizeof(resp));
    resp.code = shm_tensorpool_driver_responseCode_OK;
    resp.lease_id = 1;
    resp.stream_id = 10000;
    resp.epoch = 1;
    resp.layout_version = 1;
    resp.header_nslots = 128;
    resp.header_slot_bytes = TP_HEADER_SLOT_BYTES;
    resp.max_dims = shm_tensorpool_control_tensorHeader_maxDims();
    resp.pool_count = 1;
    resp.pools[0].pool_id = 1;
    resp.pools[0].nslots = 128;
    resp.pools[0].stride_bytes = 4096;
    strcpy(resp.header_uri, "shm:file?path=/dev/shm/tp_header");
    strcpy(resp.pools[0].uri, "shm:file?path=/dev/shm/tp_pool");
    return resp;
}

int main(void)
{
    tp_attach_response_t resp = make_valid_resp();
    resp.lease_id = shm_tensorpool_driver_shmAttachResponse_leaseId_null_value();
    assert(tp_validate_attach_response(&resp) == TP_ERR_PROTOCOL);

    resp = make_valid_resp();
    resp.stream_id = shm_tensorpool_driver_shmAttachResponse_streamId_null_value();
    assert(tp_validate_attach_response(&resp) == TP_ERR_PROTOCOL);

    resp = make_valid_resp();
    resp.epoch = shm_tensorpool_driver_shmAttachResponse_epoch_null_value();
    assert(tp_validate_attach_response(&resp) == TP_ERR_PROTOCOL);

    resp = make_valid_resp();
    resp.layout_version = shm_tensorpool_driver_shmAttachResponse_layoutVersion_null_value();
    assert(tp_validate_attach_response(&resp) == TP_ERR_PROTOCOL);

    resp = make_valid_resp();
    resp.header_nslots = shm_tensorpool_driver_shmAttachResponse_headerNslots_null_value();
    assert(tp_validate_attach_response(&resp) == TP_ERR_PROTOCOL);

    resp = make_valid_resp();
    resp.header_slot_bytes = shm_tensorpool_driver_shmAttachResponse_headerSlotBytes_null_value();
    assert(tp_validate_attach_response(&resp) == TP_ERR_PROTOCOL);

    resp = make_valid_resp();
    resp.max_dims = shm_tensorpool_driver_shmAttachResponse_maxDims_null_value();
    assert(tp_validate_attach_response(&resp) == TP_ERR_PROTOCOL);

    resp = make_valid_resp();
    resp.header_uri[0] = '\0';
    assert(tp_validate_attach_response(&resp) == TP_ERR_PROTOCOL);

    resp = make_valid_resp();
    resp.pool_count = 0;
    assert(tp_validate_attach_response(&resp) == TP_ERR_PROTOCOL);

    return 0;
}
