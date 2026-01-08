#include "tp_internal.h"

tp_err_t tp_lease_keepalive(tp_client_t *client, uint64_t lease_id, uint32_t stream_id, uint32_t client_id, uint8_t role)
{
    if (client == NULL)
    {
        return TP_ERR_ARG;
    }

    aeron_buffer_claim_t claim;
    const uint64_t msg_len = shm_tensorpool_driver_messageHeader_encoded_length() +
        shm_tensorpool_driver_shmLeaseKeepalive_sbe_block_length();
    const int64_t position = aeron_publication_try_claim(client->driver.pub, msg_len, &claim);
    if (position < 0)
    {
        return TP_ERR_AERON;
    }

    struct shm_tensorpool_driver_messageHeader hdr;
    struct shm_tensorpool_driver_shmLeaseKeepalive keepalive;
    shm_tensorpool_driver_shmLeaseKeepalive_wrap_and_apply_header(
        &keepalive,
        (char *)claim.data,
        0,
        msg_len,
        &hdr);

    shm_tensorpool_driver_shmLeaseKeepalive_set_leaseId(&keepalive, lease_id);
    shm_tensorpool_driver_shmLeaseKeepalive_set_streamId(&keepalive, stream_id);
    shm_tensorpool_driver_shmLeaseKeepalive_set_clientId(&keepalive, client_id);
    shm_tensorpool_driver_shmLeaseKeepalive_set_role(&keepalive, role);
    shm_tensorpool_driver_shmLeaseKeepalive_set_clientTimestampNs(&keepalive, tp_now_ns());

    aeron_buffer_claim_commit(&claim);
    return TP_OK;
}
