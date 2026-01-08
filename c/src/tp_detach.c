#include "tp_internal.h"

static tp_err_t tp_send_detach(tp_client_t *client, uint64_t lease_id, uint32_t stream_id, uint32_t client_id, uint8_t role, int64_t *correlation_id)
{
    aeron_buffer_claim_t claim;
    uint64_t msg_len = shm_tensorpool_driver_messageHeader_encoded_length() +
        shm_tensorpool_driver_shmDetachRequest_sbe_block_length();
    int64_t position = aeron_publication_try_claim(client->driver.pub, msg_len, &claim);
    if (position < 0)
    {
        return TP_ERR_AERON;
    }

    struct shm_tensorpool_driver_messageHeader hdr;
    struct shm_tensorpool_driver_shmDetachRequest req;
    shm_tensorpool_driver_shmDetachRequest_wrap_and_apply_header(
        &req,
        (char *)claim.data,
        0,
        msg_len,
        &hdr);

    *correlation_id = client->next_correlation_id++;
    shm_tensorpool_driver_shmDetachRequest_set_correlationId(&req, *correlation_id);
    shm_tensorpool_driver_shmDetachRequest_set_leaseId(&req, lease_id);
    shm_tensorpool_driver_shmDetachRequest_set_streamId(&req, stream_id);
    shm_tensorpool_driver_shmDetachRequest_set_clientId(&req, client_id);
    shm_tensorpool_driver_shmDetachRequest_set_role(&req, role);

    aeron_buffer_claim_commit(&claim);
    return TP_OK;
}

tp_err_t tp_detach(tp_client_t *client, uint64_t lease_id, uint32_t stream_id, uint32_t client_id, uint8_t role)
{
    if (client == NULL)
    {
        return TP_ERR_ARG;
    }
    int64_t correlation_id = 0;
    tp_err_t err = tp_send_detach(client, lease_id, stream_id, client_id, role, &correlation_id);
    if (err != TP_OK)
    {
        return err;
    }

    const uint64_t deadline = tp_now_ns() + 5000000000ULL;
    while (tp_now_ns() < deadline)
    {
        tp_client_do_work(client);
        if (client->driver.last_detach_correlation == correlation_id)
        {
            return client->driver.last_detach_code == shm_tensorpool_driver_responseCode_OK ? TP_OK : TP_ERR_PROTOCOL;
        }
    }
    return TP_ERR_TIMEOUT;
}
