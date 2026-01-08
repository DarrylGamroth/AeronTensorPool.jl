"""
Consumer handle returned by attach_consumer.
"""
mutable struct ConsumerHandle
    client::TensorPoolClient
    driver_client::DriverClientState
    consumer_agent::ConsumerAgent
end

"""
Producer handle returned by attach_producer.
"""
mutable struct ProducerHandle
    client::TensorPoolClient
    driver_client::DriverClientState
    producer_agent::ProducerAgent
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
"""
function offer_frame!(
    handle::ProducerHandle,
    payload::AbstractVector{UInt8},
    shape::AbstractVector{Int32},
    strides::AbstractVector{Int32},
    dtype::Dtype.SbeEnum,
    meta_version::UInt32,
)
    return offer_frame!(handle.producer_agent.state, payload, shape, strides, dtype, meta_version)
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
Convenience wrapper for committing a claimed slot via a ProducerHandle.
"""
function commit_slot!(
    handle::ProducerHandle,
    claim::SlotClaim,
    values_len::Int,
    shape::AbstractVector{Int32},
    strides::AbstractVector{Int32},
    dtype::Dtype.SbeEnum,
    meta_version::UInt32,
)
    return commit_slot!(
        handle.producer_agent.state,
        claim,
        values_len,
        shape,
        strides,
        dtype,
        meta_version,
    )
end

"""
Convenience wrapper for with_claimed_slot! via a ProducerHandle.
"""
function with_claimed_slot!(
    fill_fn::Function,
    handle::ProducerHandle,
    values_len::Int,
    shape::AbstractVector{Int32},
    strides::AbstractVector{Int32},
    dtype::Dtype.SbeEnum,
    meta_version::UInt32,
)
    return with_claimed_slot!(
        fill_fn,
        handle.producer_agent.state,
        values_len,
        shape,
        strides,
        dtype,
        meta_version,
    )
end

"""
Set producer metadata for a ProducerHandle.
"""
function set_metadata!(
    handle::ProducerHandle,
    meta_version::UInt32,
    name::AbstractString;
    summary::AbstractString = "",
    attributes::AbstractVector{MetadataAttribute} = MetadataAttribute[],
)
    return set_metadata!(
        handle.producer_agent.state,
        meta_version,
        name;
        summary = summary,
        attributes = attributes,
    )
end
