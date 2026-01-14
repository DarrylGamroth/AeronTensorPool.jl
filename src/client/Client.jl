module Client

using Agent
using ..Core
using ..Core.TPLog: @tp_debug, @tp_info, @tp_warn, @tp_error
using ..Aeron
using ..Control
using ..Timers
using ..DiscoveryClient
using ..Driver
using ..AeronUtils
using ..Agents
using ..ShmTensorpoolControl
using ..StringViews
using Clocks
using SnowflakeId
using UnsafeArrays
import ..Agents.Producer: offer_frame!, try_claim_slot!, try_claim_slot_by_size!, commit_slot!, with_claimed_slot!, announce_data_source!, metadata_version, set_metadata_attribute!, set_metadata_attributes!, delete_metadata_attribute!, set_metadata!

include("context.jl")
include("callbacks.jl")
include("handles.jl")
include("discovery.jl")
include("attach.jl")
include("qos_monitor.jl")
include("metadata.jl")
include("tracelink.jl")

export DriverClientState,
    TensorPoolContext,
    TensorPoolClient,
    ConsumerHandle,
    ProducerHandle,
    ConsumerConnections,
    ProducerConnections,
    AttachRequestHandle,
    ClientCallbacks,
    connect,
    do_work,
    consumer_callbacks,
    consumer_connected,
    consumer_connections,
    handle_agent,
    handle_state,
    init_driver_client,
    driver_client_do_work!,
    send_attach_request!,
    attach,
    request_attach,
    poll_attach!,
    producer_callbacks,
    producer_connected,
    producer_connections,
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
    TraceIdGenerator,
    TraceLinkContext,
    TraceLinkPublisher,
    next_trace_id!,
    trace_id_for_output!,
    new_trace_id_from_parents!,
    reuse_trace_id,
    enable_tracing!,
    encode_tracelink_set!,
    decode_tracelink_set!,
    emit_tracelink!,
    emit_tracelink_set!,
    offer_frame!,
    try_claim_slot!,
    try_claim_slot_by_size!,
    commit_slot!,
    with_claimed_slot!

end
