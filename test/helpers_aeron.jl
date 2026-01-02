using Aeron
using UnsafeArrays

const TEST_TIMEOUT_SEC = get(ENV, "AERON_TEST_TIMEOUT_SEC", "5.0") |> x -> parse(Float64, x)

import Base: show
function show(io::IO, a::UnsafeArrays.UnsafeArray{T, N}) where {T, N}
    print(io, "UnsafeArray{$(T),$(N)}(pointer=", pointer(a), ", size=", size(a), ")")
end

function wait_for(predicate::Function; timeout::Float64=TEST_TIMEOUT_SEC, sleep_s::Float64=0.0)
    start_time = time()
    while true
        predicate() && return true
        if time() - start_time > timeout
            return false
        end
        if sleep_s > 0
            sleep(sleep_s)
        else
            yield()
        end
    end
end

function canonical_shm_paths(
    base_dir::AbstractString;
    namespace::AbstractString = "tensorpool",
    producer_instance_id::AbstractString = "test-producer",
    epoch::Integer = 1,
    pool_id::Integer = 1,
)
    epoch_dir = joinpath(base_dir, namespace, producer_instance_id, "epoch-$(epoch)")
    header_path = joinpath(epoch_dir, "header.ring")
    pool_path = joinpath(epoch_dir, "payload-$(pool_id).pool")
    return epoch_dir, header_path, pool_path
end

function prepare_canonical_shm_layout(
    base_dir::AbstractString;
    namespace::AbstractString = "tensorpool",
    producer_instance_id::AbstractString = "test-producer",
    epoch::Integer = 1,
    pool_id::Integer = 1,
)
    epoch_dir, header_path, pool_path = canonical_shm_paths(
        base_dir;
        namespace = namespace,
        producer_instance_id = producer_instance_id,
        epoch = epoch,
        pool_id = pool_id,
    )
    mkpath(epoch_dir)
    return epoch_dir, header_path, pool_path
end

function with_embedded_driver(f::Function)
    Aeron.MediaDriver.launch_embedded() do driver
        f(driver)
    end
end

function with_driver_and_client(f::Function)
    with_embedded_driver() do driver
        with_client(; driver = driver) do client
            f(driver, client)
        end
    end
end

function with_client(f::Function; driver)
    Aeron.Context() do context
        Aeron.aeron_dir!(context, Aeron.MediaDriver.aeron_dir(driver))
        Aeron.Client(context) do client
            f(client)
        end
    end
end

function close_consumer_state!(state::ConsumerState)
    try
        close(state.runtime.control.pub_control)
        close(state.runtime.pub_qos)
        close(state.runtime.sub_descriptor)
        close(state.runtime.control.sub_control)
        close(state.runtime.sub_qos)
        state.runtime.sub_progress === nothing || close(state.runtime.sub_progress)
    catch
    end
    return nothing
end

function close_producer_state!(state::ProducerState)
    try
        close(state.runtime.pub_descriptor)
        close(state.runtime.control.pub_control)
        close(state.runtime.pub_qos)
        close(state.runtime.pub_metadata)
        close(state.runtime.control.sub_control)
        for entry in values(state.consumer_streams)
            entry.descriptor_pub === nothing || close(entry.descriptor_pub)
            entry.control_pub === nothing || close(entry.control_pub)
        end
    catch
    end
    return nothing
end

function close_supervisor_state!(state::SupervisorState)
    try
        close(state.runtime.control.pub_control)
        close(state.runtime.control.sub_control)
        close(state.runtime.sub_qos)
    catch
    end
    return nothing
end

function close_driver_state!(state::DriverState)
    try
        close(state.runtime.control.pub_control)
        close(state.runtime.pub_announce)
        close(state.runtime.pub_qos)
        close(state.runtime.control.sub_control)
    catch
    end
    return nothing
end

"""
Poll until an attach response with the given correlation id is received.
"""
function await_attach!(
    state::DriverClientState,
    correlation_id::Int64;
    timeout_ns::UInt64 = 5_000_000_000,
)
    now_ns = time_ns()
    deadline = now_ns + timeout_ns
    while now_ns < deadline
        attach = poll_attach!(state, correlation_id, now_ns)
        attach !== nothing && return attach
        yield()
        now_ns = time_ns()
    end
    return nothing
end
