#include <assert.h>
#include <string.h>

#include "tp_internal.h"

int main(void)
{
    assert(tp_validate_stride_bytes(4096, false) == TP_OK);
    assert(tp_validate_stride_bytes(5000, false) == TP_ERR_PROTOCOL);
    assert(tp_validate_stride_bytes(4096, true) == TP_ERR_UNSUPPORTED);

    tp_shm_mapping_t mapping;
    memset(&mapping, 0, sizeof(mapping));
    tp_err_t err = tp_shm_map("shm:file?path=/dev/shm/does-not-exist|require_hugepages=true", 128, false, &mapping);
    assert(err == TP_ERR_UNSUPPORTED);

    return 0;
}
