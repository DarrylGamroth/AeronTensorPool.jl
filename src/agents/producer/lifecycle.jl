"""
Remap producer SHM and epoch from a driver attach response.
"""
function remap_producer_from_attach!(state::ProducerState, attach::AttachResponse)
    attach.code == DriverResponseCode.OK || return false
    driver_config = producer_config_from_attach(state.config, attach)
    ispow2(driver_config.nslots) || return false
    for pool in driver_config.payload_pools
        pool.nslots == driver_config.nslots || return false
    end

    mappings = map_producer_from_attach(driver_config, attach)
    mappings === nothing && return false

    state.config = driver_config
    state.mappings = mappings
    state.epoch = attach.epoch
    state.seq = UInt64(0)
    state.emit_announce = false
    state.driver_active = true
    return true
end

function producer_driver_active(state::ProducerState)
    dc = state.driver_client
    dc === nothing && return true
    return state.driver_active && dc.lease_id != 0 && !dc.revoked && !dc.shutdown
end

"""
Handle driver revocations and reattach when a lease is invalidated.
"""
function handle_driver_events!(state::ProducerState, now_ns::UInt64)
    dc = state.driver_client
    dc === nothing && return 0
    work_count = 0

    if dc.revoked || dc.shutdown
        state.driver_active = false
    end

    if !state.driver_active && state.pending_attach_id == 0
        cid = send_attach_request!(
            dc;
            stream_id = state.config.stream_id,
            expected_layout_version = state.config.layout_version,
            max_dims = UInt8(0),
            publish_mode = DriverPublishMode.REQUIRE_EXISTING,
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
                state.driver_active = remap_producer_from_attach!(state, attach)
                state.driver_active || (dc.lease_id = UInt64(0))
            else
                state.driver_active = false
            end
        end
    end
    return work_count
end
