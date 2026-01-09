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
using ..ShmTensorpoolControl
using ..StringViews
using Clocks
using UnsafeArrays
import ..Agents.Producer: offer_frame!, try_claim_slot!, try_claim_slot_by_size!, commit_slot!, with_claimed_slot!, announce_data_source!, metadata_version, set_metadata_attribute!, set_metadata_attributes!, delete_metadata_attribute!, set_metadata!

include("context.jl")
include("callbacks.jl")
include("handles.jl")
include("discovery.jl")
include("attach.jl")
include("qos_monitor.jl")
include("metadata.jl")

export DriverClientState,
    TensorPoolContext,
    TensorPoolClient,
    ConsumerHandle,
    ProducerHandle,
    AttachRequestHandle,
    ClientCallbacks,
    connect,
    do_work,
    consumer_callbacks,
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
    producer_callbacks,
    QosMonitor,
    QosProducerSnapshot,
    QosConsumerSnapshot,
    poll_qos!,
    producer_qos,
    consumer_qos,
    MetadataAttribute,
    MetadataEntry,
    MetadataPublisher,
    MetadataCache,
    emit_metadata_announce!,
    emit_metadata_meta!,
    poll_metadata!,
    metadata_entry,
    announce_data_source!,
    metadata_version,
    set_metadata_attribute!,
    set_metadata_attributes!,
    delete_metadata_attribute!,
    set_metadata!,
    offer_frame!,
    try_claim_slot!,
    try_claim_slot_by_size!,
    commit_slot!,
    with_claimed_slot!

end
