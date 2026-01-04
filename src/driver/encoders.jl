const DRIVER_GROUP_HEADER_LEN = 4

"""
Emit a ShmAttachResponse message.

Arguments:
- `state`: driver state.
- `correlation_id`: request correlation id.
- `code`: response code enum.
- `lease_id`: lease identifier (or null value).
- `lease_expiry_ns`: lease expiry timestamp (or null value).
- `stream_state`: stream state (optional).
- `error_message`: optional error message.

Returns:
- `true` if the message was committed, `false` otherwise.
"""
function emit_attach_response!(
    state::DriverState,
    correlation_id::Int64,
    code::DriverResponseCode.SbeEnum,
    error_message::String,
    stream_state::Union{DriverStreamState, Nothing},
    lease_id::UInt64 = typemax(UInt64),
    lease_expiry_ns::UInt64 = typemax(UInt64),
)
    payload_count = isnothing(stream_state) ? 0 : length(stream_state.profile.payload_pools)
    header_uri_len = isnothing(stream_state) ? 0 : sizeof(stream_state.header_uri)
    error_len = isempty(error_message) ? 0 : sizeof(error_message)
    pools_len = 0
    if !isnothing(stream_state)
        for pool in stream_state.profile.payload_pools
            pools_len += 10
            pools_len += ShmAttachResponse.PayloadPools.regionUri_header_length
            pools_len += sizeof(stream_state.pool_uris[pool.pool_id])
        end
    end

    msg_len = DRIVER_MESSAGE_HEADER_LEN +
        Int(ShmAttachResponse.sbe_block_length(ShmAttachResponse.Decoder)) +
        DRIVER_GROUP_HEADER_LEN +
        pools_len +
        (isnothing(stream_state) ? ShmAttachResponse.headerRegionUri_header_length :
         ShmAttachResponse.headerRegionUri_header_length + header_uri_len) +
        (isempty(error_message) ? ShmAttachResponse.errorMessage_header_length :
         ShmAttachResponse.errorMessage_header_length + error_len)

    return let st = state,
        correlation_id = correlation_id,
        code = code,
        lease_id = lease_id,
        lease_expiry_ns = lease_expiry_ns,
        stream_state = stream_state,
        error_message = error_message,
        payload_count = payload_count
        @info "emit_attach_response" correlation_id code lease_id lease_expiry_ns
        sent = with_claimed_buffer!(st.runtime.control.pub_control, st.runtime.control_claim, msg_len) do buf
            ShmAttachResponse.wrap_and_apply_header!(st.runtime.attach_encoder, buf, 0)
            ShmAttachResponse.correlationId!(st.runtime.attach_encoder, correlation_id)
            ShmAttachResponse.code!(st.runtime.attach_encoder, code)

            if code == DriverResponseCode.OK && !isnothing(stream_state)
                ShmAttachResponse.leaseId!(st.runtime.attach_encoder, lease_id)
                ShmAttachResponse.leaseExpiryTimestampNs!(st.runtime.attach_encoder, lease_expiry_ns)
                ShmAttachResponse.streamId!(st.runtime.attach_encoder, stream_state.stream_id)
                ShmAttachResponse.epoch!(st.runtime.attach_encoder, stream_state.epoch)
                ShmAttachResponse.layoutVersion!(st.runtime.attach_encoder, UInt32(1))
                ShmAttachResponse.headerNslots!(st.runtime.attach_encoder, stream_state.profile.header_nslots)
                ShmAttachResponse.headerSlotBytes!(st.runtime.attach_encoder, UInt16(HEADER_SLOT_BYTES))
                ShmAttachResponse.maxDims!(st.runtime.attach_encoder, stream_state.profile.max_dims)
                ShmAttachResponse.headerRegionUri!(st.runtime.attach_encoder, stream_state.header_uri)
                pools_group = ShmAttachResponse.payloadPools!(st.runtime.attach_encoder, payload_count)
                for pool in stream_state.profile.payload_pools
                    entry = ShmAttachResponse.PayloadPools.next!(pools_group)
                    ShmAttachResponse.PayloadPools.poolId!(entry, pool.pool_id)
                    ShmAttachResponse.PayloadPools.poolNslots!(entry, stream_state.profile.header_nslots)
                    ShmAttachResponse.PayloadPools.strideBytes!(entry, pool.stride_bytes)
                    ShmAttachResponse.PayloadPools.regionUri!(entry, stream_state.pool_uris[pool.pool_id])
                end
                ShmAttachResponse.errorMessage!(st.runtime.attach_encoder, error_message)
            else
                ShmAttachResponse.leaseId!(st.runtime.attach_encoder, typemax(UInt64))
                ShmAttachResponse.leaseExpiryTimestampNs!(st.runtime.attach_encoder, typemax(UInt64))
                ShmAttachResponse.streamId!(st.runtime.attach_encoder, typemax(UInt32))
                ShmAttachResponse.epoch!(st.runtime.attach_encoder, typemax(UInt64))
                ShmAttachResponse.layoutVersion!(st.runtime.attach_encoder, typemax(UInt32))
                ShmAttachResponse.headerNslots!(st.runtime.attach_encoder, typemax(UInt32))
                ShmAttachResponse.headerSlotBytes!(st.runtime.attach_encoder, typemax(UInt16))
                ShmAttachResponse.maxDims!(st.runtime.attach_encoder, typemax(UInt8))
                ShmAttachResponse.headerRegionUri!(st.runtime.attach_encoder, "")
                ShmAttachResponse.payloadPools!(st.runtime.attach_encoder, 0)
                ShmAttachResponse.errorMessage!(st.runtime.attach_encoder, error_message)
            end
        end
        if sent
            st.metrics.attach_responses += 1
        else
            st.metrics.attach_response_drops += 1
        end
        return sent
    end
end

"""
Emit a ShmDetachResponse message.

Arguments:
- `state`: driver state.
- `correlation_id`: request correlation id.
- `code`: response code enum.
- `error_message`: optional error message.

Returns:
- `true` if the message was committed, `false` otherwise.
"""
function emit_detach_response!(
    state::DriverState,
    correlation_id::Int64,
    code::DriverResponseCode.SbeEnum,
    error_message::String,
)
    msg_len = DRIVER_MESSAGE_HEADER_LEN +
        Int(ShmDetachResponse.sbe_block_length(ShmDetachResponse.Decoder)) +
        ShmDetachResponse.errorMessage_header_length +
        sizeof(error_message)

    return let st = state,
        correlation_id = correlation_id,
        code = code,
        error_message = error_message
        with_claimed_buffer!(st.runtime.control.pub_control, st.runtime.control_claim, msg_len) do buf
            ShmDetachResponse.wrap_and_apply_header!(st.runtime.detach_encoder, buf, 0)
            ShmDetachResponse.correlationId!(st.runtime.detach_encoder, correlation_id)
            ShmDetachResponse.code!(st.runtime.detach_encoder, code)
            ShmDetachResponse.errorMessage!(st.runtime.detach_encoder, error_message)
        end && (st.metrics.detach_responses += 1; true)
    end
end

"""
Emit a ShmLeaseRevoked message.

Arguments:
- `state`: driver state.
- `lease_id`: lease identifier.
- `stream_id`: stream identifier.
- `client_id`: client identifier.
- `role`: driver role enum.
- `reason`: revoke reason enum.
- `error_message`: optional error message.

Returns:
- `true` if the message was committed, `false` otherwise.
"""
function emit_lease_revoked!(
    state::DriverState,
    lease::DriverLease,
    reason::DriverLeaseRevokeReason.SbeEnum,
    now_ns::UInt64,
)
    msg_len = DRIVER_MESSAGE_HEADER_LEN +
        Int(ShmLeaseRevoked.sbe_block_length(ShmLeaseRevoked.Decoder)) +
        ShmLeaseRevoked.errorMessage_header_length
    return let st = state,
        lease = lease,
        reason = reason,
        now_ns = now_ns
        with_claimed_buffer!(st.runtime.control.pub_control, st.runtime.control_claim, msg_len) do buf
            ShmLeaseRevoked.wrap_and_apply_header!(st.runtime.revoke_encoder, buf, 0)
            ShmLeaseRevoked.timestampNs!(st.runtime.revoke_encoder, now_ns)
            ShmLeaseRevoked.leaseId!(st.runtime.revoke_encoder, lease.lease_id)
            ShmLeaseRevoked.streamId!(st.runtime.revoke_encoder, lease.stream_id)
            ShmLeaseRevoked.clientId!(st.runtime.revoke_encoder, lease.client_id)
            ShmLeaseRevoked.role!(st.runtime.revoke_encoder, lease.role)
            ShmLeaseRevoked.reason!(st.runtime.revoke_encoder, reason)
            ShmLeaseRevoked.errorMessage!(st.runtime.revoke_encoder, "")
        end && (st.metrics.lease_revoked += 1; true)
    end
end

"""
Emit a ShmPoolAnnounce message for a stream.

Arguments:
- `state`: driver state.
- `stream_state`: stream state snapshot.

Returns:
- `true` if the message was committed, `false` otherwise.
"""
function emit_driver_announce!(state::DriverState, stream_state::DriverStreamState)
    payload_count = length(stream_state.profile.payload_pools)
    msg_len = MESSAGE_HEADER_LEN +
        Int(ShmPoolAnnounce.sbe_block_length(ShmPoolAnnounce.Decoder)) +
        4 +
        sum(
            10 + ShmPoolAnnounce.PayloadPools.regionUri_header_length +
            sizeof(stream_state.pool_uris[pool.pool_id])
            for pool in stream_state.profile.payload_pools
        ) +
        ShmPoolAnnounce.headerRegionUri_header_length +
        sizeof(stream_state.header_uri)

    return let st = state,
        stream_state = stream_state,
        payload_count = payload_count,
        now_ns = (st.now_ns == 0 ? UInt64(Clocks.time_nanos(st.clock)) : st.now_ns)
        with_claimed_buffer!(st.runtime.pub_announce, st.runtime.control_claim, msg_len) do buf
            ShmPoolAnnounce.wrap_and_apply_header!(st.runtime.announce_encoder, buf, 0)
            ShmPoolAnnounce.streamId!(st.runtime.announce_encoder, stream_state.stream_id)
            ShmPoolAnnounce.producerId!(st.runtime.announce_encoder, UInt32(0))
            ShmPoolAnnounce.epoch!(st.runtime.announce_encoder, stream_state.epoch)
            ShmPoolAnnounce.announceTimestampNs!(st.runtime.announce_encoder, now_ns)
            ShmPoolAnnounce.layoutVersion!(st.runtime.announce_encoder, UInt32(1))
            ShmPoolAnnounce.headerNslots!(st.runtime.announce_encoder, stream_state.profile.header_nslots)
            ShmPoolAnnounce.headerSlotBytes!(st.runtime.announce_encoder, UInt16(HEADER_SLOT_BYTES))
            ShmPoolAnnounce.maxDims!(st.runtime.announce_encoder, stream_state.profile.max_dims)

            pools_group = ShmPoolAnnounce.payloadPools!(st.runtime.announce_encoder, payload_count)
            for pool in stream_state.profile.payload_pools
                entry = ShmPoolAnnounce.PayloadPools.next!(pools_group)
                ShmPoolAnnounce.PayloadPools.poolId!(entry, pool.pool_id)
                ShmPoolAnnounce.PayloadPools.poolNslots!(entry, stream_state.profile.header_nslots)
                ShmPoolAnnounce.PayloadPools.strideBytes!(entry, pool.stride_bytes)
                ShmPoolAnnounce.PayloadPools.regionUri!(entry, stream_state.pool_uris[pool.pool_id])
            end
            ShmPoolAnnounce.headerRegionUri!(st.runtime.announce_encoder, stream_state.header_uri)
        end && (st.metrics.announces += 1; true)
    end
end

"""
Emit a ShmDriverShutdown message.

Arguments:
- `state`: driver state.
- `reason`: shutdown reason enum.
- `error_message`: optional error message.

Returns:
- `true` if the message was committed, `false` otherwise.
"""
function emit_driver_shutdown!(
    state::DriverState,
    reason::DriverShutdownReason.SbeEnum = DriverShutdownReason.NORMAL,
    error_message::String = "",
)
    msg_len = DRIVER_MESSAGE_HEADER_LEN +
        Int(ShmDriverShutdown.sbe_block_length(ShmDriverShutdown.Decoder)) +
        ShmDriverShutdown.errorMessage_header_length +
        sizeof(error_message)
    now_ns = state.now_ns
    return let st = state,
        now_ns = now_ns,
        reason = reason,
        error_message = error_message
        with_claimed_buffer!(st.runtime.control.pub_control, st.runtime.control_claim, msg_len) do buf
            ShmDriverShutdown.wrap_and_apply_header!(st.runtime.shutdown_encoder, buf, 0)
            ShmDriverShutdown.timestampNs!(st.runtime.shutdown_encoder, now_ns)
            ShmDriverShutdown.reason!(st.runtime.shutdown_encoder, reason)
            ShmDriverShutdown.errorMessage!(st.runtime.shutdown_encoder, error_message)
        end
    end
end
