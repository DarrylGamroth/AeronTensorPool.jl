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

function with_embedded_driver(f::Function)
    Aeron.MediaDriver.launch_embedded() do driver
        f(driver)
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
        close(state.pub_control)
        close(state.pub_qos)
        close(state.sub_descriptor)
        close(state.sub_control)
        close(state.sub_qos)
        close(state.client)
        close(state.ctx)
    catch
    end
    return nothing
end

function close_producer_state!(state::ProducerState)
    try
        close(state.pub_descriptor)
        close(state.pub_control)
        close(state.pub_qos)
        close(state.pub_metadata)
        close(state.sub_control)
        close(state.client)
        close(state.ctx)
    catch
    end
    return nothing
end

function close_supervisor_state!(state::SupervisorState)
    try
        close(state.pub_control)
        close(state.sub_control)
        close(state.sub_qos)
        close(state.client)
        close(state.ctx)
    catch
    end
    return nothing
end
