module Client

using Agent
using ..Core
using ..Aeron
using ..Control
using ..Timers
using ..Discovery
using ..Driver
using ..AeronUtils
using ..Agents
import ..Agents.Producer: offer_frame!, try_claim_slot!, commit_slot!, with_claimed_slot!

include("client_api.jl")

export DriverClientState,
    TensorPoolContext,
    TensorPoolClient,
    ConsumerHandle,
    ProducerHandle,
    AttachRequestHandle,
    connect,
    do_work,
    handle_agent,
    handle_state,
    init_driver_client,
    driver_client_do_work!,
    send_attach_request!,
    attach_consumer,
    attach_producer,
    request_attach_consumer,
    request_attach_producer,
    poll_attach!,
    offer_frame!,
    try_claim_slot!,
    commit_slot!,
    with_claimed_slot!

end
