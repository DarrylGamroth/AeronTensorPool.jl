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
    namespace::AbstractString = "default",
    stream_id::Integer = 10000,
    epoch::Integer = 1,
    pool_id::Integer = 1,
    producer_instance_id::Union{Nothing, AbstractString} = nothing,
)
    user = AeronTensorPool.Shm.canonical_user_name()
    epoch_dir = joinpath(base_dir, "tensorpool-$(user)", namespace, string(stream_id), string(epoch))
    header_path = joinpath(epoch_dir, "header.ring")
    pool_path = joinpath(epoch_dir, "$(pool_id).pool")
    return epoch_dir, header_path, pool_path
end

function prepare_canonical_shm_layout(
    base_dir::AbstractString;
    namespace::AbstractString = "default",
    stream_id::Integer = 10000,
    epoch::Integer = 1,
    pool_id::Integer = 1,
    producer_instance_id::Union{Nothing, AbstractString} = nothing,
)
    epoch_dir, header_path, pool_path = canonical_shm_paths(
        base_dir;
        namespace = namespace,
        stream_id = stream_id,
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
        close(state.runtime.sub_qos)
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
        AeronTensorPool.Driver.cleanup_shm_on_exit!(state)
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
    timeout_ns::UInt64 = UInt64(5_000_000_000),
)
    now_ns = time_ns()
    deadline = now_ns + timeout_ns
    while now_ns < deadline
        attach = AeronTensorPool.Control.poll_attach!(state, correlation_id, now_ns)
        attach !== nothing && return attach
        yield()
        now_ns = time_ns()
    end
    return nothing
end

function test_producer_config(
    base_dir::AbstractString;
    aeron_dir::AbstractString = "",
    stream_id::UInt32 = UInt32(10000),
    producer_id::UInt32 = UInt32(7),
    nslots::UInt32 = UInt32(8),
    stride_bytes::UInt32 = UInt32(4096),
    pool_id::UInt16 = UInt16(1),
    producer_instance_id::AbstractString = "test-producer",
    descriptor_stream_id::Int32 = Int32(1100),
    control_stream_id::Int32 = Int32(1000),
    qos_stream_id::Int32 = Int32(1200),
    metadata_stream_id::Int32 = Int32(1300),
)
    pools = [PayloadPoolConfig(pool_id, "", stride_bytes, nslots)]
    header_uri, resolved_pools = AeronTensorPool.resolve_producer_paths(
        "",
        pools,
        base_dir,
        "tensorpool",
        stream_id,
        UInt64(1),
    )
    cfg = default_producer_config(;
        aeron_dir = aeron_dir,
        stream_id = stream_id,
        producer_id = producer_id,
        nslots = nslots,
        shm_base_dir = base_dir,
        producer_instance_id = producer_instance_id,
        payload_pools = pools,
        descriptor_stream_id = descriptor_stream_id,
        control_stream_id = control_stream_id,
        qos_stream_id = qos_stream_id,
        metadata_stream_id = metadata_stream_id,
    )
    return ProducerConfig(
        cfg.aeron_dir,
        cfg.aeron_uri,
        cfg.descriptor_stream_id,
        cfg.control_stream_id,
        cfg.qos_stream_id,
        cfg.metadata_stream_id,
        cfg.stream_id,
        cfg.producer_id,
        cfg.layout_version,
        cfg.nslots,
        cfg.shm_base_dir,
        cfg.shm_namespace,
        cfg.producer_instance_id,
        header_uri,
        resolved_pools,
        cfg.max_dims,
        cfg.announce_interval_ns,
        cfg.qos_interval_ns,
        cfg.progress_interval_ns,
        cfg.progress_bytes_delta,
        cfg.mlock_shm,
    )
end

function test_consumer_config(
    base_dir::AbstractString;
    aeron_dir::AbstractString = "",
    stream_id::UInt32 = UInt32(10000),
    consumer_id::UInt32 = UInt32(42),
    descriptor_stream_id::Int32 = Int32(1100),
    control_stream_id::Int32 = Int32(1000),
    qos_stream_id::Int32 = Int32(1200),
    supports_progress::Bool = false,
)
    return default_consumer_config(;
        aeron_dir = aeron_dir,
        stream_id = stream_id,
        consumer_id = consumer_id,
        shm_base_dir = base_dir,
        descriptor_stream_id = descriptor_stream_id,
        control_stream_id = control_stream_id,
        qos_stream_id = qos_stream_id,
        supports_progress = supports_progress,
    )
end

function test_supervisor_config(;
    aeron_dir::AbstractString = "",
    stream_id::UInt32 = UInt32(10000),
    control_stream_id::Int32 = Int32(1000),
    qos_stream_id::Int32 = Int32(1200),
)
    return SupervisorConfig(
        String(aeron_dir),
        "aeron:ipc",
        control_stream_id,
        qos_stream_id,
        stream_id,
        UInt64(5_000_000_000),
        UInt64(1_000_000_000),
    )
end
