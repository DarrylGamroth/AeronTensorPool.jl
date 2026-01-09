#include <assert.h>
#include <string.h>

#include "tp_internal.h"

int main(void)
{
    tp_context_t ctx;
    memset(&ctx, 0, sizeof(ctx));
    ctx.client_id = 7;

    tp_client_t client;
    memset(&client, 0, sizeof(client));
    client.context = &ctx;

    tp_consumer_t consumer;
    memset(&consumer, 0, sizeof(consumer));
    consumer.client = &client;
    consumer.stream_id = 10000;

    uint8_t buffer[256];
    struct shm_tensorpool_control_messageHeader hdr;
    struct shm_tensorpool_control_consumerConfig cfg;
    uint64_t msg_len = shm_tensorpool_control_messageHeader_encoded_length() +
        shm_tensorpool_control_consumerConfig_sbe_block_length() +
        shm_tensorpool_control_consumerConfig_descriptorChannel_header_length() +
        shm_tensorpool_control_consumerConfig_controlChannel_header_length() +
        shm_tensorpool_control_consumerConfig_payloadFallbackUri_header_length();
    shm_tensorpool_control_consumerConfig_wrap_and_apply_header(&cfg, (char *)buffer, 0, msg_len, &hdr);
    shm_tensorpool_control_consumerConfig_set_streamId(&cfg, consumer.stream_id);
    shm_tensorpool_control_consumerConfig_set_consumerId(&cfg, ctx.client_id);
    shm_tensorpool_control_consumerConfig_set_descriptorStreamId(&cfg, 42);
    shm_tensorpool_control_consumerConfig_put_descriptorChannel(&cfg, "", 0);
    shm_tensorpool_control_consumerConfig_set_controlStreamId(&cfg, 0);
    shm_tensorpool_control_consumerConfig_put_controlChannel(&cfg, "", 0);
    shm_tensorpool_control_consumerConfig_put_payloadFallbackUri(&cfg, "", 0);

    tp_consumer_handle_control_buffer(&consumer, buffer, (size_t)msg_len);
    assert(consumer.revoked);

    return 0;
}
