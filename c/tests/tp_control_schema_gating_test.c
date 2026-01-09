#include <assert.h>
#include <string.h>

#include "tp_internal.h"

int main(void)
{
    tp_driver_client_t driver;
    memset(&driver, 0, sizeof(driver));

    uint8_t buffer[64];
    memset(buffer, 0, sizeof(buffer));
    struct shm_tensorpool_driver_messageHeader hdr;
    shm_tensorpool_driver_messageHeader_wrap(
        &hdr,
        (char *)buffer,
        0,
        shm_tensorpool_driver_messageHeader_sbe_schema_version(),
        sizeof(buffer));
    shm_tensorpool_driver_messageHeader_set_blockLength(&hdr, 0);
    shm_tensorpool_driver_messageHeader_set_templateId(&hdr, shm_tensorpool_driver_shmAttachResponse_sbe_template_id());
    shm_tensorpool_driver_messageHeader_set_schemaId(&hdr, 999);
    shm_tensorpool_driver_messageHeader_set_version(&hdr, shm_tensorpool_driver_messageHeader_sbe_schema_version());

    tp_driver_client_handle_control_buffer(&driver, buffer, sizeof(buffer));
    assert(driver.last_attach_correlation == 0);
    assert(driver.last_attach_valid == false);

    shm_tensorpool_driver_messageHeader_set_schemaId(&hdr, shm_tensorpool_driver_messageHeader_sbe_schema_id());
    shm_tensorpool_driver_messageHeader_set_templateId(&hdr, 0xFFFF);
    tp_driver_client_handle_control_buffer(&driver, buffer, sizeof(buffer));
    assert(driver.last_attach_correlation == 0);

    return 0;
}
