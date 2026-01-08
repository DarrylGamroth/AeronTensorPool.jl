#include "tp_internal.h"

static int64_t tp_next_correlation_id(tp_client_t *client)
{
    return client->next_correlation_id++;
}

tp_err_t tp_send_attach_request(
    tp_client_t *client,
    uint32_t stream_id,
    uint8_t role,
    uint8_t publish_mode)
{
    aeron_buffer_claim_t claim;
    const uint64_t msg_len = shm_tensorpool_driver_messageHeader_encoded_length() +
        shm_tensorpool_driver_shmAttachRequest_sbe_block_length();
    const int64_t position = aeron_publication_try_claim(client->driver.pub, msg_len, &claim);
    if (position < 0)
    {
        return TP_ERR_AERON;
    }

    struct shm_tensorpool_driver_messageHeader hdr;
    struct shm_tensorpool_driver_shmAttachRequest req;
    shm_tensorpool_driver_shmAttachRequest_wrap_and_apply_header(
        &req,
        (char *)claim.data,
        0,
        msg_len,
        &hdr);

    int64_t correlation_id = tp_next_correlation_id(client);
    shm_tensorpool_driver_shmAttachRequest_set_correlationId(&req, correlation_id);
    shm_tensorpool_driver_shmAttachRequest_set_streamId(&req, stream_id);
    shm_tensorpool_driver_shmAttachRequest_set_clientId(&req, client->context->client_id);
    shm_tensorpool_driver_shmAttachRequest_set_role(&req, role);
    shm_tensorpool_driver_shmAttachRequest_set_publishMode(&req, publish_mode);
    shm_tensorpool_driver_shmAttachRequest_set_expectedLayoutVersion(&req, UINT32_MAX);
    shm_tensorpool_driver_shmAttachRequest_set_maxDims(&req, UINT8_MAX);
    shm_tensorpool_driver_shmAttachRequest_set_requireHugepages(&req, shm_tensorpool_driver_hugepagesPolicy_UNSPECIFIED);

    aeron_buffer_claim_commit(&claim);
    client->driver.last_attach_correlation = correlation_id;
    return TP_OK;
}

tp_err_t tp_wait_attach(tp_client_t *client, int64_t correlation_id, tp_attach_response_t *out)
{
    const uint64_t deadline = tp_now_ns() + 5000000000ULL;
    while (tp_now_ns() < deadline)
    {
        tp_client_do_work(client);
        if (client->driver.last_attach_correlation == correlation_id)
        {
            *out = client->driver.last_attach;
            return TP_OK;
        }
    }
    return TP_ERR_TIMEOUT;
}
