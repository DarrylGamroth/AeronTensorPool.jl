const DRIVER_REGISTRY_LOCK = ReentrantLock()
const DRIVER_REGISTRY = Dict{String, DriverState}()

"""
Register a driver instance in the local registry.

Arguments:
- `state`: driver state to register.

Returns:
- `nothing`.
"""
function register_driver!(state::DriverState)
    instance_id = state.config.endpoints.instance_id
    isempty(instance_id) && error("driver instance_id is empty")
    lock(DRIVER_REGISTRY_LOCK) do
        DRIVER_REGISTRY[instance_id] = state
    end
    return nothing
end

"""
Unregister a driver instance from the local registry.

Arguments:
- `state`: driver state to unregister.

Returns:
- `nothing`.
"""
function unregister_driver!(state::DriverState)
    instance_id = state.config.endpoints.instance_id
    isempty(instance_id) && return nothing
    lock(DRIVER_REGISTRY_LOCK) do
        if get(DRIVER_REGISTRY, instance_id, nothing) === state
            delete!(DRIVER_REGISTRY, instance_id)
        end
    end
    return nothing
end

"""
Lookup a driver state by instance id.

Arguments:
- `instance_id`: driver instance id.

Returns:
- `DriverState` if found, otherwise `nothing`.
"""
function find_driver_state(instance_id::AbstractString)
    lock(DRIVER_REGISTRY_LOCK) do
        return get(DRIVER_REGISTRY, String(instance_id), nothing)
    end
end

"""
List registered driver instance ids.

Returns:
- Vector of instance id strings.
"""
function list_driver_instances()
    lock(DRIVER_REGISTRY_LOCK) do
        return collect(keys(DRIVER_REGISTRY))
    end
end
