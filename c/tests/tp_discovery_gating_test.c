#include <assert.h>
#include <string.h>

#include "tp_internal.h"

int main(void)
{
    tp_discovery_client_t client;
    memset(&client, 0, sizeof(client));

    uint8_t buffer[64];
    memset(buffer, 0, sizeof(buffer));
    struct shm_tensorpool_discovery_messageHeader hdr;
    shm_tensorpool_discovery_messageHeader_wrap(
        &hdr,
        (char *)buffer,
        0,
        shm_tensorpool_discovery_messageHeader_sbe_schema_version(),
        sizeof(buffer));
    shm_tensorpool_discovery_messageHeader_set_blockLength(&hdr, 0);
    shm_tensorpool_discovery_messageHeader_set_templateId(&hdr, shm_tensorpool_discovery_discoveryResponse_sbe_template_id());
    shm_tensorpool_discovery_messageHeader_set_schemaId(&hdr, 999);
    shm_tensorpool_discovery_messageHeader_set_version(&hdr, shm_tensorpool_discovery_messageHeader_sbe_schema_version());

    tp_discovery_client_handle_buffer(&client, (char *)buffer, sizeof(buffer));
    assert(client.entry_count == 0);
    assert(client.last_request_id == 0);

    shm_tensorpool_discovery_messageHeader_set_schemaId(&hdr, shm_tensorpool_discovery_discoveryResponse_sbe_schema_id());
    shm_tensorpool_discovery_messageHeader_set_templateId(&hdr, 0xFFFF);
    tp_discovery_client_handle_buffer(&client, (char *)buffer, sizeof(buffer));
    assert(client.entry_count == 0);
    assert(client.last_request_id == 0);

    shm_tensorpool_discovery_messageHeader_set_templateId(&hdr, shm_tensorpool_discovery_discoveryResponse_sbe_template_id());
    shm_tensorpool_discovery_messageHeader_set_version(&hdr, shm_tensorpool_discovery_messageHeader_sbe_schema_version() + 1);
    tp_discovery_client_handle_buffer(&client, (char *)buffer, sizeof(buffer));
    assert(client.entry_count == 0);
    assert(client.last_request_id == 0);

    return 0;
}
