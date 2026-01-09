#include <assert.h>
#include <string.h>

#include "tensorpool_client.h"
#include "tp_internal.h"

int main(void)
{
    tp_context_t context;
    memset(&context, 0, sizeof(context));
    context.client_id = 1234;

    tp_client_t client;
    memset(&client, 0, sizeof(client));
    client.context = &context;

    uint32_t client_id = 0;
    assert(tp_client_get_client_id(&client, &client_id) == TP_OK);
    assert(client_id == 1234);

    tp_producer_t producer;
    memset(&producer, 0, sizeof(producer));
    producer.client = &client;
    producer.lease_id = 42;
    producer.stream_id = 10000;

    uint64_t lease_id = 0;
    uint32_t stream_id = 0;
    uint32_t producer_id = 0;
    assert(tp_producer_get_lease_id(&producer, &lease_id) == TP_OK);
    assert(lease_id == 42);
    assert(tp_producer_get_stream_id(&producer, &stream_id) == TP_OK);
    assert(stream_id == 10000);
    assert(tp_producer_get_producer_id(&producer, &producer_id) == TP_OK);
    assert(producer_id == 1234);

    tp_consumer_t consumer;
    memset(&consumer, 0, sizeof(consumer));
    consumer.client = &client;
    consumer.lease_id = 77;
    consumer.stream_id = 10000;

    uint32_t consumer_id = 0;
    assert(tp_consumer_get_lease_id(&consumer, &lease_id) == TP_OK);
    assert(lease_id == 77);
    assert(tp_consumer_get_stream_id(&consumer, &stream_id) == TP_OK);
    assert(stream_id == 10000);
    assert(tp_consumer_get_consumer_id(&consumer, &consumer_id) == TP_OK);
    assert(consumer_id == 1234);

    assert(tp_err_str(TP_OK) != NULL);
    assert(tp_err_str(TP_ERR_NOT_FOUND) != NULL);

    return 0;
}
