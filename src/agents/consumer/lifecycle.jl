@inline function consumer_driver_active(state::ConsumerState)
    dc = state.driver_client
    dc === nothing && return true
    return state.driver_active && dc.lease_id != 0 && !dc.revoked && !dc.shutdown
end

"""
Remap consumer SHM from a driver attach response.
"""
function remap_consumer_from_attach!(state::ConsumerState, attach::AttachResponse)
    reset_mappings!(state)
    state.config.use_shm = true
    ok = map_from_attach_response!(state, attach)
    state.driver_active = ok
    return ok
end

"""
Handle driver revocations and reattach when a lease is invalidated.
"""
function handle_driver_events!(state::ConsumerState, now_ns::UInt64)
    dc = state.driver_client
    dc === nothing && return 0
    work_count = 0

    if dc.revoked || dc.shutdown
        state.driver_active = false
        reset_mappings!(state)
    end

    if !state.driver_active && state.pending_attach_id == 0
        cid = send_attach_request!(
            dc;
            stream_id = state.config.stream_id,
            expected_layout_version = state.config.expected_layout_version,
            max_dims = UInt8(0),
            publish_mode = DriverPublishMode.REQUIRE_EXISTING,
            require_hugepages = state.config.require_hugepages,
        )
        if cid != 0
            state.pending_attach_id = cid
            work_count += 1
        end
    end

    if state.pending_attach_id != 0
        attach = dc.poller.last_attach
        if attach !== nothing && attach.correlation_id == state.pending_attach_id
            state.pending_attach_id = Int64(0)
            if attach.code == DriverResponseCode.OK
                apply_attach!(dc, attach)
                state.driver_active = remap_consumer_from_attach!(state, attach)
                state.driver_active || (dc.lease_id = UInt64(0))
            else
                state.driver_active = false
            end
        end
    end
    return work_count
end
