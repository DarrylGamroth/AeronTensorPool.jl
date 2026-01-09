#include <assert.h>
#include <string.h>

#include "tensorpool_client.h"
#include "tp_internal.h"

int main(void)
{
    tp_client_t client;
    memset(&client, 0, sizeof(client));
    client.driver.revoked_lease_id = 99;
    client.driver.revoked_role = (uint8_t)shm_tensorpool_driver_role_CONSUMER;

    tp_consumer_t consumer;
    memset(&consumer, 0, sizeof(consumer));
    consumer.client = &client;
    consumer.lease_id = 99;

    tp_frame_view_t view;
    tp_err_t err = tp_consumer_try_read_frame(&consumer, &view);
    assert(err == TP_ERR_PROTOCOL);
    assert(consumer.revoked);

    return 0;
}
