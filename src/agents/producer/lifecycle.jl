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
    return true
end

"""
Handle driver revocations and reattach when a lease is invalidated.
"""
function handle_driver_events!(state::ProducerState, now_ns::UInt64)
    dc = state.driver_client
    dc === nothing && return 0
    work_count = 0

    if dc.revoked || dc.shutdown || dc.lease_id == 0
        Hsm.dispatch!(state.driver_lifecycle, :LeaseInvalid, state)
    end

    if Hsm.current(state.driver_lifecycle) == :Inactive && state.pending_attach_id == 0
        cid = send_attach_request!(
            dc;
            stream_id = state.config.stream_id,
            expected_layout_version = state.config.layout_version,
            publish_mode = DriverPublishMode.REQUIRE_EXISTING,
        )
        if cid != 0
            state.pending_attach_id = cid
            Hsm.dispatch!(state.driver_lifecycle, :AttachRequested, state)
            work_count += 1
        end
    end

    if state.pending_attach_id != 0
        attach = Control.poll_attach!(dc, state.pending_attach_id, now_ns)
        if attach !== nothing
            state.pending_attach_id = Int64(0)
            if attach.code == DriverResponseCode.OK
                if remap_producer_from_attach!(state, attach)
                    Hsm.dispatch!(state.driver_lifecycle, :AttachOk, state)
                else
                    dc.lease_id = UInt64(0)
                    Hsm.dispatch!(state.driver_lifecycle, :AttachFailed, state)
                end
            else
                Hsm.dispatch!(state.driver_lifecycle, :AttachFailed, state)
            end
            work_count += 1
        end
    end
    return work_count
end
