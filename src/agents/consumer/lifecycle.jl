function consumer_driver_active(state::ConsumerState)
    dc = state.driver_client
    dc === nothing && return true
    return Hsm.current(state.driver_lifecycle) == :Attached &&
           state.driver_active &&
           dc.lease_id != 0 &&
           !dc.revoked &&
           !dc.shutdown
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

const ANNOUNCE_WAIT_MULTIPLIER = UInt64(3)

function start_announce_wait!(state::ConsumerState, now_ns::UInt64, epoch::UInt64)
    state.announce_event_epoch = epoch
    state.announce_event_now_ns = now_ns
    Hsm.dispatch!(state.announce_lifecycle, :ProducerRevoke, state)
    return nothing
end

function stop_announce_wait!(state::ConsumerState)
    Hsm.dispatch!(state.announce_lifecycle, :AnnounceSeen, state)
    return nothing
end

function abort_announce_wait!(state::ConsumerState)
    Hsm.dispatch!(state.announce_lifecycle, :AbortWait, state)
    return nothing
end

function poll_announce_wait!(state::ConsumerState, now_ns::UInt64)
    if state.announce_wait_active && expired(state.announce_wait_timer, now_ns)
        @tp_warn "announce wait timed out; continuing to wait" stream_id = state.config.stream_id waiting_epoch =
            state.awaiting_announce_epoch
        state.announce_event_now_ns = now_ns
        Hsm.dispatch!(state.announce_lifecycle, :AnnounceTimeout, state)
        return 1
    end
    return 0
end

"""
Handle driver revocations and reattach when a lease is invalidated.
"""
function handle_driver_events!(state::ConsumerState, now_ns::UInt64)
    dc = state.driver_client
    dc === nothing && return 0
    work_count = 0
    lifecycle = state.driver_lifecycle
    current = Hsm.current(lifecycle)

    if current == :Attached && (dc.revoked || dc.shutdown || dc.lease_id == 0)
        Hsm.dispatch!(lifecycle, :LeaseInvalid, state)
        current = Hsm.current(lifecycle)
    end
    if current == :Backoff
        Hsm.dispatch!(lifecycle, :BackoffElapsed, state)
        current = Hsm.current(lifecycle)
    end
    revoke = dc.poller.last_revoke
    if revoke !== nothing &&
       revoke.role == DriverRole.PRODUCER &&
       revoke.stream_id == state.config.stream_id &&
       revoke.reason != DriverLeaseRevokeReason.NULL_VALUE
        if state.mappings.highest_epoch != 0
            reset_mappings!(state)
            start_announce_wait!(state, now_ns, state.mappings.highest_epoch)
        end
    end

    if current == :Unattached && state.pending_attach_id == 0
        cid = send_attach_request!(
            dc;
            stream_id = state.config.stream_id,
            expected_layout_version = state.config.expected_layout_version,
            publish_mode = DriverPublishMode.REQUIRE_EXISTING,
            require_hugepages = state.config.require_hugepages,
        )
        if cid != 0
            state.pending_attach_id = cid
            Hsm.dispatch!(lifecycle, :AttachRequested, state)
            work_count += 1
        end
    end

    if state.pending_attach_id != 0
        attach = Control.poll_attach!(dc, state.pending_attach_id, now_ns)
        if attach !== nothing
            state.pending_attach_id = Int64(0)
            if attach.code == DriverResponseCode.OK
                state.driver_active = remap_consumer_from_attach!(state, attach)
                if state.driver_active
                    Hsm.dispatch!(lifecycle, :AttachOk, state)
                else
                    dc.lease_id = UInt64(0)
                    Hsm.dispatch!(lifecycle, :AttachFailed, state)
                end
            else
                state.driver_active = false
                Hsm.dispatch!(lifecycle, :AttachFailed, state)
            end
            work_count += 1
        end
    end
    work_count += poll_announce_wait!(state, now_ns)
    return work_count
end
