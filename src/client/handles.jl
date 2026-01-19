"""
Consumer handle returned by attach.
"""
mutable struct ConsumerHandle{ClientT<:AbstractTensorPoolClient, AgentT<:ConsumerAgent}
    client::ClientT
    driver_client::DriverClientState
    consumer_agent::AgentT
end

"""
Producer handle returned by attach.
"""
mutable struct ProducerHandle{ClientT<:AbstractTensorPoolClient, AgentT<:ProducerAgent}
    client::ClientT
    driver_client::DriverClientState
    producer_agent::AgentT
end

"""
Connection status for consumer subscriptions/publications.
"""
struct ConsumerConnections
    descriptor_connected::Bool
    control_connected::Bool
    qos_connected::Bool
end

"""
Connection status for producer publications.
"""
struct ProducerConnections
    descriptor_connected::Bool
    control_connected::Bool
    qos_connected::Bool
end

"""
Return the underlying agent for a handle.
"""
handle_agent(handle::ConsumerHandle) = handle.consumer_agent
handle_agent(handle::ProducerHandle) = handle.producer_agent

"""
Return the underlying agent state for a handle.
"""
handle_state(handle::ConsumerHandle) = handle.consumer_agent.state
handle_state(handle::ProducerHandle) = handle.producer_agent.state

"""
Return the resolved stream ID for a handle.
"""
resolved_stream_id(handle::ConsumerHandle) = handle.consumer_agent.state.config.stream_id
resolved_stream_id(handle::ProducerHandle) = handle.producer_agent.state.config.stream_id

"""
Return current Aeron connection status for consumer subscriptions/publications.
"""
function consumer_connections(handle::ConsumerHandle)
    state = handle.consumer_agent.state
    return ConsumerConnections(
        Aeron.is_connected(state.runtime.sub_descriptor),
        Aeron.is_connected(state.runtime.control.sub_control),
        Aeron.is_connected(state.runtime.sub_qos),
    )
end

"""
Return true if required consumer subscriptions are connected.
"""
function consumer_connected(handle::ConsumerHandle)
    conn = consumer_connections(handle)
    state = handle.consumer_agent.state
    qos_required = state.config.qos_stream_id != 0
    return conn.descriptor_connected && conn.control_connected &&
           (!qos_required || conn.qos_connected)
end

"""
Return current Aeron connection status for producer publications.
"""
function producer_connections(handle::ProducerHandle)
    state = handle.producer_agent.state
    return ProducerConnections(
        Aeron.is_connected(state.runtime.pub_descriptor),
        Aeron.is_connected(state.runtime.control.pub_control),
        Aeron.is_connected(state.runtime.pub_qos),
    )
end

"""
Return true if required producer publications are connected.
"""
function producer_connected(handle::ProducerHandle)
    conn = producer_connections(handle)
    state = handle.producer_agent.state
    qos_required = state.config.qos_stream_id != 0
    return conn.descriptor_connected && conn.control_connected &&
           (!qos_required || conn.qos_connected)
end

"""
Close a ConsumerHandle and its resources.
"""
function Base.close(handle::ConsumerHandle)
    Agent.on_close(handle.consumer_agent)
    try
        close(handle.driver_client.pub)
        close(handle.driver_client.sub)
    catch
    end
    return nothing
end

"""
Close a ProducerHandle and its resources.
"""
function Base.close(handle::ProducerHandle)
    Agent.on_close(handle.producer_agent)
    try
        close(handle.driver_client.pub)
        close(handle.driver_client.sub)
    catch
    end
    return nothing
end

"""
Do work for a ConsumerHandle.
"""
do_work(handle::ConsumerHandle) = Agent.do_work(handle.consumer_agent)

"""
Do work for a ProducerHandle.
"""
do_work(handle::ProducerHandle) = Agent.do_work(handle.producer_agent)

"""
Convenience wrapper for publishing a frame via a ProducerHandle.

Keyword arguments:
- `trace_id`: optional trace ID (0 means unset).
"""
function offer_frame!(
    handle::ProducerHandle,
    payload::AbstractVector{UInt8},
    shape::AbstractVector{Int32},
    strides::AbstractVector{Int32},
    dtype::Dtype.SbeEnum,
    meta_version::UInt32,
    ;
    trace_id::UInt64 = UInt64(0),
)
    return offer_frame!(
        handle.producer_agent.state,
        payload,
        shape,
        strides,
        dtype,
        meta_version;
        trace_id = trace_id,
    )
end

"""
Convenience wrapper for claiming a slot via a ProducerHandle.

Returns `SlotClaim` on success, or `nothing` if no claim could be made.
"""
function try_claim_slot!(
    handle::ProducerHandle,
    pool_id::UInt16,
)
    return try_claim_slot!(handle.producer_agent.state, pool_id)
end

"""
Convenience wrapper for claiming a slot by size via a ProducerHandle.

Returns `SlotClaim` on success, or `nothing` if no pool fits or the claim failed.
"""
function try_claim_slot_by_size!(
    handle::ProducerHandle,
    values_len::Integer,
)
    return try_claim_slot_by_size!(handle.producer_agent.state, values_len)
end

"""
Convenience wrapper for committing a claimed slot via a ProducerHandle.

Keyword arguments:
- `trace_id`: optional trace ID (0 means unset).
"""
function commit_slot!(
    handle::ProducerHandle,
    claim::SlotClaim,
    values_len::Int,
    shape::AbstractVector{Int32},
    strides::AbstractVector{Int32},
    dtype::Dtype.SbeEnum,
    meta_version::UInt32,
    ;
    trace_id::UInt64 = UInt64(0),
)
    return commit_slot!(
        handle.producer_agent.state,
        claim,
        values_len,
        shape,
        strides,
        dtype,
        meta_version,
        trace_id,
    )
end

"""
Convenience wrapper for with_claimed_slot! via a ProducerHandle.

Keyword arguments:
- `trace_id`: optional trace ID (0 means unset).
"""
function with_claimed_slot!(
    fill_fn::Function,
    handle::ProducerHandle,
    values_len::Int,
    shape::AbstractVector{Int32},
    strides::AbstractVector{Int32},
    dtype::Dtype.SbeEnum,
    meta_version::UInt32,
    ;
    trace_id::UInt64 = UInt64(0),
)
    return with_claimed_slot!(
        fill_fn,
        handle.producer_agent.state,
        values_len,
        shape,
        strides,
        dtype,
        meta_version,
        trace_id,
    )
end

"""
Set producer metadata for a ProducerHandle.

This increments the metadata version and queues an announce+meta update to be emitted
by the producer work loop.
"""
function set_metadata!(
    handle::ProducerHandle,
    name::AbstractString;
    summary::AbstractString = "",
    attributes::AbstractVector{MetadataAttribute} = MetadataAttribute[],
)
    return set_metadata!(
        handle.producer_agent.state,
        name;
        summary = summary,
        attributes = attributes,
    )
end

"""
Announce data source name/summary for a ProducerHandle.

This increments the metadata version and queues an announce update to be emitted by
the producer work loop.
"""
function announce_data_source!(
    handle::ProducerHandle,
    name::AbstractString;
    summary::AbstractString = "",
)
    return announce_data_source!(
        handle.producer_agent.state,
        name;
        summary = summary,
    )
end

"""
Set metadata attributes for a ProducerHandle without changing the data source name.

This increments the metadata version and queues a meta update to be emitted by the
producer work loop.
"""
function set_metadata_attributes!(
    handle::ProducerHandle;
    attributes::AbstractVector{MetadataAttribute} = MetadataAttribute[],
)
    return set_metadata_attributes!(
        handle.producer_agent.state;
        attributes = attributes,
    )
end

"""
Upsert a metadata attribute for a ProducerHandle.

This increments the metadata version and queues a meta update to be emitted by the
producer work loop.
"""
function set_metadata_attribute!(
    handle::ProducerHandle,
    key::AbstractString,
    format::AbstractString,
    value::AbstractVector{UInt8},
)
    return set_metadata_attribute!(
        handle.producer_agent.state,
        key,
        format,
        value,
    )
end

function set_metadata_attribute!(
    handle::ProducerHandle,
    key::AbstractString,
    format::AbstractString,
    value::AbstractString,
)
    return set_metadata_attribute!(
        handle.producer_agent.state,
        key,
        format,
        value,
    )
end

function set_metadata_attribute!(
    handle::ProducerHandle,
    key::AbstractString,
    format::AbstractString,
    value::Integer,
)
    return set_metadata_attribute!(
        handle.producer_agent.state,
        key,
        format,
        value,
    )
end

function set_metadata_attribute!(
    handle::ProducerHandle,
    attribute::MetadataAttribute,
)
    return set_metadata_attribute!(handle.producer_agent.state, attribute)
end

function set_metadata_attribute!(
    handle::ProducerHandle,
    kv::Pair{<:AbstractString, <:Tuple{<:AbstractString, Any}},
)
    return set_metadata_attribute!(handle.producer_agent.state, kv)
end

function set_metadata_attribute!(
    handle::ProducerHandle,
    kv::Pair{<:AbstractString, <:NamedTuple{(:format, :value), <:Tuple{<:AbstractString, Any}}},
)
    return set_metadata_attribute!(handle.producer_agent.state, kv)
end

"""
Delete a metadata attribute for a ProducerHandle.

This increments the metadata version and queues a meta update to be emitted by the
producer work loop.
"""
function delete_metadata_attribute!(
    handle::ProducerHandle,
    key::AbstractString,
)
    return delete_metadata_attribute!(
        handle.producer_agent.state,
        key,
    )
end

"""
Return the current metadata version for a ProducerHandle.
"""
metadata_version(handle::ProducerHandle) = metadata_version(handle.producer_agent.state)
