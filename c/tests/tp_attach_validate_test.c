#include <assert.h>
#include <string.h>

#include "tp_internal.h"

int main(void)
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
    strcpy(resp.header_uri, "shm:file?path=/dev/shm/tp_header");
    resp.pool_count = 1;
    resp.pools[0].pool_id = 1;
    resp.pools[0].nslots = 128;
    resp.pools[0].stride_bytes = 4096;
    strcpy(resp.pools[0].uri, "shm:file?path=/dev/shm/tp_pool");

    assert(tp_validate_attach_response(&resp) == TP_OK);

    resp.header_uri[0] = '\0';
    assert(tp_validate_attach_response(&resp) == TP_ERR_PROTOCOL);

    resp.header_uri[0] = 's';
    resp.pool_count = 0;
    assert(tp_validate_attach_response(&resp) == TP_ERR_PROTOCOL);

    resp.pool_count = 1;
    resp.pools[0].nslots = 64;
    assert(tp_validate_attach_response(&resp) == TP_ERR_PROTOCOL);

    return 0;
}
