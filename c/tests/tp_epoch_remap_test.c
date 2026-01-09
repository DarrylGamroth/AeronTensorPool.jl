#include <assert.h>
#include <string.h>

#include "tensorpool_client.h"
#include "tp_internal.h"

static void init_consumer(tp_consumer_t *consumer, tp_client_t *client)
{
    memset(consumer, 0, sizeof(*consumer));
    consumer->client = client;
    consumer->lease_id = 1;
    consumer->stream_id = 10000;
    consumer->epoch = 2;
    consumer->last_epoch = 1;
    consumer->header_nslots = 8;
    consumer->header_slot_bytes = TP_HEADER_SLOT_BYTES;
    consumer->pool_count = 1;
    consumer->has_descriptor = true;
    consumer->last_seq = 1;
    consumer->last_header_index = 0;
}

int main(void)
{
    tp_client_t client;
    memset(&client, 0, sizeof(client));
    tp_consumer_t consumer;
    init_consumer(&consumer, &client);

    tp_frame_view_t view;
    tp_err_t err = tp_consumer_try_read_frame(&consumer, &view);
    assert(err == TP_ERR_PROTOCOL);
    assert(consumer.revoked);

    return 0;
}
