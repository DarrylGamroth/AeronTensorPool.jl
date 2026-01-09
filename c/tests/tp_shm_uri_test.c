#include <assert.h>
#include <string.h>

#include "tp_internal.h"

int main(void)
{
    bool require_hugepages = false;

    tp_err_t err = tp_shm_validate_uri("shm:file?path=/dev/shm/tp_header", &require_hugepages);
    assert(err == TP_OK);
    assert(require_hugepages == false);

    require_hugepages = false;
    err = tp_shm_validate_uri("shm:file?path=/dev/shm/tp|require_hugepages=true", &require_hugepages);
    assert(err == TP_OK);
    assert(require_hugepages == true);

    require_hugepages = false;
    err = tp_shm_validate_uri("shm:file?path=/dev/shm/tp|unknown_param=1", &require_hugepages);
    assert(err == TP_ERR_PROTOCOL);

    require_hugepages = false;
    err = tp_shm_validate_uri("file?path=/dev/shm/tp", &require_hugepages);
    assert(err == TP_ERR_PROTOCOL);

    require_hugepages = false;
    err = tp_shm_validate_uri("shm:file?path=relative", &require_hugepages);
    assert(err == TP_ERR_PROTOCOL);

    err = tp_validate_stride_bytes(0, false);
    assert(err == TP_ERR_PROTOCOL);

    err = tp_validate_stride_bytes(4096, false);
    assert(err == TP_OK);

    err = tp_validate_stride_bytes(4096, true);
    assert(err == TP_ERR_UNSUPPORTED);

    return 0;
}
