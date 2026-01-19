#!/usr/bin/env julia
using Agent
using Aeron
using AeronTensorPool
using Logging
using StringViews
using UnsafeArrays
include(joinpath(@__DIR__, "script_errors.jl"))

const C = AeronTensorPool.Core

struct RawValue
    value::String
end

@inline function format_value(value)
    value isa RawValue && return value.value
    if value isa AbstractString
        return repr(value)
    end
    return string(value)
end

@inline function append_field!(io::IO, first::Bool, key::AbstractString, value)
    if !first
        print(io, ' ')
    end
    print(io, key, '=')
    print(io, format_value(value))
    return false
end

function log_message!(io::IO, ctx, schema::AbstractString, msg_type::AbstractString, fields::NamedTuple; flush_logs::Bool)
    first = true
    first = append_field!(io, first, "ts_ns", time_ns())
    first = append_field!(io, first, "schema", schema)
    first = append_field!(io, first, "type", msg_type)
    first = append_field!(io, first, "label", ctx.label)
    first = append_field!(io, first, "channel", ctx.channel)
    first = append_field!(io, first, "stream_id", ctx.stream_id)
    for (key, value) in pairs(fields)
        first = append_field!(io, first, String(key), value)
    end
    println(io)
    flush_logs && Base.flush(io)
    return nothing
end

function format_pools(pools, pool_module)
    buf = IOBuffer()
    print(buf, '[')
    first = true
    for pool in pools
        first || print(buf, ',')
        first = false
        print(buf, "{pool_id=", pool_module.poolId(pool))
        print(buf, ",pool_nslots=", pool_module.poolNslots(pool))
        print(buf, ",stride_bytes=", pool_module.strideBytes(pool))
        print(buf, ",region_uri=", repr(String(pool_module.regionUri(pool, StringView))))
        print(buf, '}')
    end
    print(buf, ']')
    return RawValue(String(take!(buf)))
end

function format_metadata_attrs(attrs)
    buf = IOBuffer()
    print(buf, '[')
    first = true
    for attr in attrs
        first || print(buf, ',')
        first = false
        key = String(C.DataSourceMeta.Attributes.key(attr, StringView))
        format = String(C.DataSourceMeta.Attributes.format(attr, StringView))
        value = C.DataSourceMeta.Attributes.value(attr)
        print(buf, "{key=", repr(key), ",format=", repr(format), ",value=", repr(value), "}")
    end
    print(buf, ']')
    return RawValue(String(take!(buf)))
end

function var_ascii_view(dec::AeronTensorPool.ShmTensorpoolDiscovery.VarAsciiEncoding.Decoder)
    len = AeronTensorPool.ShmTensorpoolDiscovery.VarAsciiEncoding.length(dec)
    offset = dec.offset + AeronTensorPool.ShmTensorpoolDiscovery.VarAsciiEncoding.varData_encoding_offset(dec)
    return StringView(view(dec.buffer, offset + 1:offset + len))
end

function format_discovery_tags(tags, tag_module)
    buf = IOBuffer()
    print(buf, '[')
    first = true
    for tag_entry in tags
        tag_decoder = tag_module.tag(tag_entry)
        tag_view = var_ascii_view(tag_decoder)
        tag_len = AeronTensorPool.ShmTensorpoolDiscovery.VarAsciiEncoding.length(tag_decoder)
        pos = tag_module.sbe_position(tag_entry)
        tag_module.sbe_position!(tag_entry, pos + C.DISCOVERY_VAR_ASCII_HEADER_LEN + tag_len)
        isempty(tag_view) && continue
        first || print(buf, ',')
        first = false
        print(buf, repr(String(tag_view)))
    end
    print(buf, ']')
    return RawValue(String(take!(buf)))
end

struct TapDecoders
    frame_descriptor::C.FrameDescriptor.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    frame_progress::C.FrameProgress.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    consumer_config::C.ConsumerConfigMsg.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    consumer_hello::C.ConsumerHello.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    qos_producer::C.QosProducer.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    qos_consumer::C.QosConsumer.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    shm_pool_announce::C.ShmPoolAnnounce.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    data_source_announce::C.DataSourceAnnounce.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    data_source_meta::C.DataSourceMeta.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    attach_request::C.ShmAttachRequest.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    attach_response::C.ShmAttachResponse.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    detach_request::C.ShmDetachRequest.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    detach_response::C.ShmDetachResponse.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    lease_keepalive::C.ShmLeaseKeepalive.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    lease_revoked::C.ShmLeaseRevoked.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    driver_shutdown::C.ShmDriverShutdown.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    shutdown_request::C.ShmDriverShutdownRequest.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    discovery_request::C.DiscoveryRequest.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    discovery_response::C.DiscoveryResponse.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    bridge_chunk::C.BridgeFrameChunk.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    tracelink_set::C.TraceLinkSet.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
end

function TapDecoders()
    return TapDecoders(
        C.FrameDescriptor.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        C.FrameProgress.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        C.ConsumerConfigMsg.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        C.ConsumerHello.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        C.QosProducer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        C.QosConsumer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        C.ShmPoolAnnounce.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        C.DataSourceAnnounce.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        C.DataSourceMeta.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        C.ShmAttachRequest.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        C.ShmAttachResponse.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        C.ShmDetachRequest.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        C.ShmDetachResponse.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        C.ShmLeaseKeepalive.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        C.ShmLeaseRevoked.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        C.ShmDriverShutdown.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        C.ShmDriverShutdownRequest.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        C.DiscoveryRequest.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        C.DiscoveryResponse.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        C.BridgeFrameChunk.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        C.TraceLinkSet.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
    )
end

mutable struct TapState
    io::IO
    flush_logs::Bool
    decoders::TapDecoders
end

struct TapHandlerState
    tap::TapState
    label::String
    channel::String
    stream_id::Int32
end

struct TapSubscription
    label::String
    channel::String
    stream_id::Int32
    subscription::Aeron.Subscription
    assembler::Aeron.FragmentAssembler
end

mutable struct TapAgent
    state::TapState
    subscriptions::Vector{TapSubscription}
    fragment_limit::Int32
end

Agent.name(::TapAgent) = "aeron-tap"

function Agent.do_work(agent::TapAgent)
    total = 0
    for sub in agent.subscriptions
        total += Aeron.poll(sub.subscription, sub.assembler, agent.fragment_limit)
    end
    return total
end

function Agent.on_close(agent::TapAgent)
    for sub in agent.subscriptions
        close(sub.subscription)
    end
    return nothing
end

function log_decode_error!(tap::TapState, ctx::TapHandlerState, schema::AbstractString, template_id, err)
    log_message!(tap.io, ctx, schema, "DecodeError", (
        template_id = template_id,
        error = sprint(showerror, err),
    ); flush_logs = tap.flush_logs)
    return nothing
end

function handle_control_message!(tap::TapState, ctx::TapHandlerState, buffer::AbstractVector{UInt8})
    length(buffer) < C.MESSAGE_HEADER_LEN && return false
    header = C.MessageHeader.Decoder(buffer, 0)
    if !C.matches_message_schema(header, C.MessageHeader.sbe_schema_version(C.MessageHeader.Decoder))
        return false
    end
    template_id = C.MessageHeader.templateId(header)
    schema_id = C.MessageHeader.schemaId(header)
    block_len = C.MessageHeader.blockLength(header)
    version = C.MessageHeader.version(header)

    try
        if template_id == C.TEMPLATE_FRAME_DESCRIPTOR
            C.FrameDescriptor.wrap!(tap.decoders.frame_descriptor, buffer, 0; header = header)
            msg = tap.decoders.frame_descriptor
            log_message!(tap.io, ctx, "control", "FrameDescriptor", (
                template_id = template_id,
                schema_id = schema_id,
                block_length = block_len,
                version = version,
                msg_stream_id = C.FrameDescriptor.streamId(msg),
                epoch = C.FrameDescriptor.epoch(msg),
                seq = C.FrameDescriptor.seq(msg),
                timestamp_ns = C.FrameDescriptor.timestampNs(msg),
                meta_version = C.FrameDescriptor.metaVersion(msg),
                trace_id = C.FrameDescriptor.traceId(msg),
            ); flush_logs = tap.flush_logs)
            return true
        elseif template_id == C.TEMPLATE_FRAME_PROGRESS
            C.FrameProgress.wrap!(tap.decoders.frame_progress, buffer, 0; header = header)
            msg = tap.decoders.frame_progress
            log_message!(tap.io, ctx, "control", "FrameProgress", (
                template_id = template_id,
                schema_id = schema_id,
                block_length = block_len,
                version = version,
                msg_stream_id = C.FrameProgress.streamId(msg),
                epoch = C.FrameProgress.epoch(msg),
                seq = C.FrameProgress.seq(msg),
                payload_bytes_filled = C.FrameProgress.payloadBytesFilled(msg),
                state = C.FrameProgress.state(msg),
            ); flush_logs = tap.flush_logs)
            return true
        elseif template_id == C.TEMPLATE_SHM_POOL_ANNOUNCE
            C.ShmPoolAnnounce.wrap!(tap.decoders.shm_pool_announce, buffer, 0; header = header)
            msg = tap.decoders.shm_pool_announce
            pools = C.ShmPoolAnnounce.payloadPools(msg)
            payload_pools = format_pools(pools, C.ShmPoolAnnounce.PayloadPools)
            header_region_uri = String(C.ShmPoolAnnounce.headerRegionUri(msg, StringView))
            log_message!(tap.io, ctx, "control", "ShmPoolAnnounce", (
                template_id = template_id,
                schema_id = schema_id,
                block_length = block_len,
                version = version,
                msg_stream_id = C.ShmPoolAnnounce.streamId(msg),
                producer_id = C.ShmPoolAnnounce.producerId(msg),
                epoch = C.ShmPoolAnnounce.epoch(msg),
                announce_timestamp_ns = C.ShmPoolAnnounce.announceTimestampNs(msg),
                announce_clock_domain = C.ShmPoolAnnounce.announceClockDomain(msg),
                layout_version = C.ShmPoolAnnounce.layoutVersion(msg),
                header_nslots = C.ShmPoolAnnounce.headerNslots(msg),
                header_slot_bytes = C.ShmPoolAnnounce.headerSlotBytes(msg),
                header_region_uri = header_region_uri,
                payload_pools = payload_pools,
            ); flush_logs = tap.flush_logs)
            return true
        elseif template_id == C.TEMPLATE_CONSUMER_CONFIG
            C.ConsumerConfigMsg.wrap!(tap.decoders.consumer_config, buffer, 0; header = header)
            msg = tap.decoders.consumer_config
            log_message!(tap.io, ctx, "control", "ConsumerConfig", (
                template_id = template_id,
                schema_id = schema_id,
                block_length = block_len,
                version = version,
                msg_stream_id = C.ConsumerConfigMsg.streamId(msg),
                consumer_id = C.ConsumerConfigMsg.consumerId(msg),
                use_shm = C.ConsumerConfigMsg.useShm(msg),
                mode = C.ConsumerConfigMsg.mode(msg),
                descriptor_stream_id = C.ConsumerConfigMsg.descriptorStreamId(msg),
                control_stream_id = C.ConsumerConfigMsg.controlStreamId(msg),
                payload_fallback_uri = String(C.ConsumerConfigMsg.payloadFallbackUri(msg, StringView)),
                descriptor_channel = String(C.ConsumerConfigMsg.descriptorChannel(msg, StringView)),
                control_channel = String(C.ConsumerConfigMsg.controlChannel(msg, StringView)),
            ); flush_logs = tap.flush_logs)
            return true
        elseif template_id == C.TEMPLATE_CONSUMER_HELLO
            C.ConsumerHello.wrap!(tap.decoders.consumer_hello, buffer, 0; header = header)
            msg = tap.decoders.consumer_hello
            var_ok = AeronTensorPool.Core.consumer_hello_var_data_ok(msg)
            log_message!(tap.io, ctx, "control", "ConsumerHello", (
                template_id = template_id,
                schema_id = schema_id,
                block_length = block_len,
                version = version,
                var_data_ok = var_ok,
                msg_stream_id = C.ConsumerHello.streamId(msg),
                consumer_id = C.ConsumerHello.consumerId(msg),
                supports_shm = C.ConsumerHello.supportsShm(msg),
                supports_progress = C.ConsumerHello.supportsProgress(msg),
                mode = C.ConsumerHello.mode(msg),
                max_rate_hz = C.ConsumerHello.maxRateHz(msg),
                expected_layout_version = C.ConsumerHello.expectedLayoutVersion(msg),
                progress_interval_us = C.ConsumerHello.progressIntervalUs(msg),
                progress_bytes_delta = C.ConsumerHello.progressBytesDelta(msg),
                progress_major_delta_units = C.ConsumerHello.progressMajorDeltaUnits(msg),
                descriptor_stream_id = C.ConsumerHello.descriptorStreamId(msg),
                control_stream_id = C.ConsumerHello.controlStreamId(msg),
                descriptor_channel = String(C.ConsumerHello.descriptorChannel(msg, StringView)),
                control_channel = String(C.ConsumerHello.controlChannel(msg, StringView)),
            ); flush_logs = tap.flush_logs)
            return true
        elseif template_id == C.TEMPLATE_QOS_PRODUCER
            C.QosProducer.wrap!(tap.decoders.qos_producer, buffer, 0; header = header)
            msg = tap.decoders.qos_producer
            log_message!(tap.io, ctx, "control", "QosProducer", (
                template_id = template_id,
                schema_id = schema_id,
                block_length = block_len,
                version = version,
                msg_stream_id = C.QosProducer.streamId(msg),
                producer_id = C.QosProducer.producerId(msg),
                epoch = C.QosProducer.epoch(msg),
                current_seq = C.QosProducer.currentSeq(msg),
            ); flush_logs = tap.flush_logs)
            return true
        elseif template_id == C.TEMPLATE_QOS_CONSUMER
            C.QosConsumer.wrap!(tap.decoders.qos_consumer, buffer, 0; header = header)
            msg = tap.decoders.qos_consumer
            log_message!(tap.io, ctx, "control", "QosConsumer", (
                template_id = template_id,
                schema_id = schema_id,
                block_length = block_len,
                version = version,
                msg_stream_id = C.QosConsumer.streamId(msg),
                consumer_id = C.QosConsumer.consumerId(msg),
                epoch = C.QosConsumer.epoch(msg),
                mode = C.QosConsumer.mode(msg),
                last_seq_seen = C.QosConsumer.lastSeqSeen(msg),
                drops_gap = C.QosConsumer.dropsGap(msg),
                drops_late = C.QosConsumer.dropsLate(msg),
            ); flush_logs = tap.flush_logs)
            return true
        elseif template_id == C.TEMPLATE_DATA_SOURCE_ANNOUNCE
            C.DataSourceAnnounce.wrap!(tap.decoders.data_source_announce, buffer, 0; header = header)
            msg = tap.decoders.data_source_announce
            log_message!(tap.io, ctx, "control", "DataSourceAnnounce", (
                template_id = template_id,
                schema_id = schema_id,
                block_length = block_len,
                version = version,
                msg_stream_id = C.DataSourceAnnounce.streamId(msg),
                producer_id = C.DataSourceAnnounce.producerId(msg),
                epoch = C.DataSourceAnnounce.epoch(msg),
                meta_version = C.DataSourceAnnounce.metaVersion(msg),
                name = String(C.DataSourceAnnounce.name(msg, StringView)),
                summary = String(C.DataSourceAnnounce.summary(msg, StringView)),
            ); flush_logs = tap.flush_logs)
            return true
        elseif template_id == C.TEMPLATE_DATA_SOURCE_META
            C.DataSourceMeta.wrap!(tap.decoders.data_source_meta, buffer, 0; header = header)
            msg = tap.decoders.data_source_meta
            attrs = C.DataSourceMeta.attributes(msg)
            log_message!(tap.io, ctx, "control", "DataSourceMeta", (
                template_id = template_id,
                schema_id = schema_id,
                block_length = block_len,
                version = version,
                msg_stream_id = C.DataSourceMeta.streamId(msg),
                meta_version = C.DataSourceMeta.metaVersion(msg),
                timestamp_ns = C.DataSourceMeta.timestampNs(msg),
                attributes = format_metadata_attrs(attrs),
            ); flush_logs = tap.flush_logs)
            return true
        else
            log_message!(tap.io, ctx, "control", "Unknown", (
                template_id = template_id,
                schema_id = schema_id,
                block_length = block_len,
                version = version,
                buffer_len = length(buffer),
            ); flush_logs = tap.flush_logs)
            return true
        end
    catch err
        log_decode_error!(tap, ctx, "control", template_id, err)
        return true
    end
end

function handle_driver_message!(tap::TapState, ctx::TapHandlerState, buffer::AbstractVector{UInt8})
    length(buffer) < C.DRIVER_MESSAGE_HEADER_LEN && return false
    header = C.DriverMessageHeader.Decoder(buffer, 0)
    if !C.matches_driver_schema(
        header,
        C.DriverMessageHeader.sbe_schema_id(C.DriverMessageHeader.Decoder),
        C.ShmAttachResponse.sbe_schema_version(C.ShmAttachResponse.Decoder),
    )
        return false
    end
    template_id = C.DriverMessageHeader.templateId(header)
    schema_id = C.DriverMessageHeader.schemaId(header)
    block_len = C.DriverMessageHeader.blockLength(header)
    version = C.DriverMessageHeader.version(header)

    try
        if template_id == C.TEMPLATE_SHM_ATTACH_REQUEST
            C.ShmAttachRequest.wrap!(tap.decoders.attach_request, buffer, 0; header = header)
            msg = tap.decoders.attach_request
            log_message!(tap.io, ctx, "driver", "ShmAttachRequest", (
                template_id = template_id,
                schema_id = schema_id,
                block_length = block_len,
                version = version,
                correlation_id = C.ShmAttachRequest.correlationId(msg),
                msg_stream_id = C.ShmAttachRequest.streamId(msg),
                client_id = C.ShmAttachRequest.clientId(msg),
                role = C.ShmAttachRequest.role(msg),
                expected_layout_version = C.ShmAttachRequest.expectedLayoutVersion(msg),
                publish_mode = C.ShmAttachRequest.publishMode(msg),
                require_hugepages = C.ShmAttachRequest.requireHugepages(msg),
                desired_node_id = C.ShmAttachRequest.desiredNodeId(msg),
            ); flush_logs = tap.flush_logs)
            return true
        elseif template_id == C.TEMPLATE_SHM_ATTACH_RESPONSE
            C.ShmAttachResponse.wrap!(tap.decoders.attach_response, buffer, 0; header = header)
            msg = tap.decoders.attach_response
            pools = C.ShmAttachResponse.payloadPools(msg)
            payload_pools = format_pools(pools, C.ShmAttachResponse.PayloadPools)
            header_region_uri = String(C.ShmAttachResponse.headerRegionUri(msg, StringView))
            error_message = String(C.ShmAttachResponse.errorMessage(msg, StringView))
            log_message!(tap.io, ctx, "driver", "ShmAttachResponse", (
                template_id = template_id,
                schema_id = schema_id,
                block_length = block_len,
                version = version,
                correlation_id = C.ShmAttachResponse.correlationId(msg),
                code = C.ShmAttachResponse.code(msg),
                lease_id = C.ShmAttachResponse.leaseId(msg),
                lease_expiry_ns = C.ShmAttachResponse.leaseExpiryTimestampNs(msg),
                msg_stream_id = C.ShmAttachResponse.streamId(msg),
                epoch = C.ShmAttachResponse.epoch(msg),
                layout_version = C.ShmAttachResponse.layoutVersion(msg),
                header_nslots = C.ShmAttachResponse.headerNslots(msg),
                header_slot_bytes = C.ShmAttachResponse.headerSlotBytes(msg),
                node_id = C.ShmAttachResponse.nodeId(msg),
                header_region_uri = header_region_uri,
                payload_pools = payload_pools,
                error_message = error_message,
            ); flush_logs = tap.flush_logs)
            return true
        elseif template_id == C.TEMPLATE_SHM_DETACH_REQUEST
            C.ShmDetachRequest.wrap!(tap.decoders.detach_request, buffer, 0; header = header)
            msg = tap.decoders.detach_request
            log_message!(tap.io, ctx, "driver", "ShmDetachRequest", (
                template_id = template_id,
                schema_id = schema_id,
                block_length = block_len,
                version = version,
                correlation_id = C.ShmDetachRequest.correlationId(msg),
                lease_id = C.ShmDetachRequest.leaseId(msg),
                msg_stream_id = C.ShmDetachRequest.streamId(msg),
                client_id = C.ShmDetachRequest.clientId(msg),
                role = C.ShmDetachRequest.role(msg),
            ); flush_logs = tap.flush_logs)
            return true
        elseif template_id == C.TEMPLATE_SHM_DETACH_RESPONSE
            C.ShmDetachResponse.wrap!(tap.decoders.detach_response, buffer, 0; header = header)
            msg = tap.decoders.detach_response
            log_message!(tap.io, ctx, "driver", "ShmDetachResponse", (
                template_id = template_id,
                schema_id = schema_id,
                block_length = block_len,
                version = version,
                correlation_id = C.ShmDetachResponse.correlationId(msg),
                code = C.ShmDetachResponse.code(msg),
                error_message = String(C.ShmDetachResponse.errorMessage(msg, StringView)),
            ); flush_logs = tap.flush_logs)
            return true
        elseif template_id == C.TEMPLATE_SHM_LEASE_KEEPALIVE
            C.ShmLeaseKeepalive.wrap!(tap.decoders.lease_keepalive, buffer, 0; header = header)
            msg = tap.decoders.lease_keepalive
            log_message!(tap.io, ctx, "driver", "ShmLeaseKeepalive", (
                template_id = template_id,
                schema_id = schema_id,
                block_length = block_len,
                version = version,
                lease_id = C.ShmLeaseKeepalive.leaseId(msg),
                msg_stream_id = C.ShmLeaseKeepalive.streamId(msg),
                client_id = C.ShmLeaseKeepalive.clientId(msg),
                role = C.ShmLeaseKeepalive.role(msg),
                client_timestamp_ns = C.ShmLeaseKeepalive.clientTimestampNs(msg),
            ); flush_logs = tap.flush_logs)
            return true
        elseif template_id == C.TEMPLATE_SHM_LEASE_REVOKED
            C.ShmLeaseRevoked.wrap!(tap.decoders.lease_revoked, buffer, 0; header = header)
            msg = tap.decoders.lease_revoked
            log_message!(tap.io, ctx, "driver", "ShmLeaseRevoked", (
                template_id = template_id,
                schema_id = schema_id,
                block_length = block_len,
                version = version,
                timestamp_ns = C.ShmLeaseRevoked.timestampNs(msg),
                lease_id = C.ShmLeaseRevoked.leaseId(msg),
                msg_stream_id = C.ShmLeaseRevoked.streamId(msg),
                client_id = C.ShmLeaseRevoked.clientId(msg),
                role = C.ShmLeaseRevoked.role(msg),
                reason = C.ShmLeaseRevoked.reason(msg),
                error_message = String(C.ShmLeaseRevoked.errorMessage(msg, StringView)),
            ); flush_logs = tap.flush_logs)
            return true
        elseif template_id == C.TEMPLATE_SHM_DRIVER_SHUTDOWN
            C.ShmDriverShutdown.wrap!(tap.decoders.driver_shutdown, buffer, 0; header = header)
            msg = tap.decoders.driver_shutdown
            log_message!(tap.io, ctx, "driver", "ShmDriverShutdown", (
                template_id = template_id,
                schema_id = schema_id,
                block_length = block_len,
                version = version,
                timestamp_ns = C.ShmDriverShutdown.timestampNs(msg),
                reason = C.ShmDriverShutdown.reason(msg),
                error_message = String(C.ShmDriverShutdown.errorMessage(msg, StringView)),
            ); flush_logs = tap.flush_logs)
            return true
        elseif template_id == C.TEMPLATE_SHM_DRIVER_SHUTDOWN_REQUEST
            C.ShmDriverShutdownRequest.wrap!(tap.decoders.shutdown_request, buffer, 0; header = header)
            msg = tap.decoders.shutdown_request
            var_ok = AeronTensorPool.Core.driver_shutdown_request_var_data_ok(msg)
            log_message!(tap.io, ctx, "driver", "ShmDriverShutdownRequest", (
                template_id = template_id,
                schema_id = schema_id,
                block_length = block_len,
                version = version,
                var_data_ok = var_ok,
                correlation_id = C.ShmDriverShutdownRequest.correlationId(msg),
                reason = C.ShmDriverShutdownRequest.reason(msg),
                token = String(C.ShmDriverShutdownRequest.token(msg, StringView)),
                error_message = String(C.ShmDriverShutdownRequest.errorMessage(msg, StringView)),
            ); flush_logs = tap.flush_logs)
            return true
        else
            log_message!(tap.io, ctx, "driver", "Unknown", (
                template_id = template_id,
                schema_id = schema_id,
                block_length = block_len,
                version = version,
                buffer_len = length(buffer),
            ); flush_logs = tap.flush_logs)
            return true
        end
    catch err
        log_decode_error!(tap, ctx, "driver", template_id, err)
        return true
    end
end

function handle_discovery_message!(tap::TapState, ctx::TapHandlerState, buffer::AbstractVector{UInt8})
    length(buffer) < C.DISCOVERY_MESSAGE_HEADER_LEN && return false
    header = C.DiscoveryMessageHeader.Decoder(buffer, 0)
    if C.DiscoveryMessageHeader.schemaId(header) !=
       C.DiscoveryMessageHeader.sbe_schema_id(C.DiscoveryMessageHeader.Decoder)
        return false
    end
    if C.DiscoveryMessageHeader.version(header) !=
       C.DiscoveryMessageHeader.sbe_schema_version(C.DiscoveryMessageHeader.Decoder)
        return false
    end
    template_id = C.DiscoveryMessageHeader.templateId(header)
    schema_id = C.DiscoveryMessageHeader.schemaId(header)
    block_len = C.DiscoveryMessageHeader.blockLength(header)
    version = C.DiscoveryMessageHeader.version(header)

    try
        if template_id == C.TEMPLATE_DISCOVERY_REQUEST
            C.DiscoveryRequest.wrap!(tap.decoders.discovery_request, buffer, 0; header = header)
            msg = tap.decoders.discovery_request
            tags = C.DiscoveryRequest.tags(msg)
            tags_str = format_discovery_tags(tags, C.DiscoveryRequest.Tags)
            response_channel = String(C.DiscoveryRequest.responseChannel(msg, StringView))
            data_source_name = String(C.DiscoveryRequest.dataSourceName(msg, StringView))
            log_message!(tap.io, ctx, "discovery", "DiscoveryRequest", (
                template_id = template_id,
                schema_id = schema_id,
                block_length = block_len,
                version = version,
                request_id = C.DiscoveryRequest.requestId(msg),
                client_id = C.DiscoveryRequest.clientId(msg),
                response_stream_id = C.DiscoveryRequest.responseStreamId(msg),
                msg_stream_id = C.DiscoveryRequest.streamId(msg),
                producer_id = C.DiscoveryRequest.producerId(msg),
                data_source_id = C.DiscoveryRequest.dataSourceId(msg),
                response_channel = response_channel,
                data_source_name = data_source_name,
                tags = tags_str,
            ); flush_logs = tap.flush_logs)
            return true
        elseif template_id == C.TEMPLATE_DISCOVERY_RESPONSE
            C.DiscoveryResponse.wrap!(tap.decoders.discovery_response, buffer, 0; header = header)
            msg = tap.decoders.discovery_response
            results = C.DiscoveryResponse.results(msg)
            results_str = IOBuffer()
            print(results_str, '[')
            first = true
            for result in results
                first || print(results_str, ',')
                first = false
                pools = C.DiscoveryResponse.Results.payloadPools(result)
                tags = C.DiscoveryResponse.Results.tags(result)
                print(results_str, "{stream_id=", C.DiscoveryResponse.Results.streamId(result))
                print(results_str, ",producer_id=", C.DiscoveryResponse.Results.producerId(result))
                print(results_str, ",epoch=", C.DiscoveryResponse.Results.epoch(result))
                print(results_str, ",layout_version=", C.DiscoveryResponse.Results.layoutVersion(result))
                print(results_str, ",header_nslots=", C.DiscoveryResponse.Results.headerNslots(result))
                print(results_str, ",header_slot_bytes=", C.DiscoveryResponse.Results.headerSlotBytes(result))
                print(results_str, ",max_dims=", C.DiscoveryResponse.Results.maxDims(result))
                print(results_str, ",data_source_id=", C.DiscoveryResponse.Results.dataSourceId(result))
                print(results_str, ",driver_control_stream_id=", C.DiscoveryResponse.Results.driverControlStreamId(result))
                print(results_str, ",pools=", format_value(format_pools(pools, C.DiscoveryResponse.Results.PayloadPools)))
                print(results_str, ",tags=", format_value(format_discovery_tags(tags, C.DiscoveryResponse.Results.Tags)))
                print(results_str, ",header_region_uri=", repr(String(C.DiscoveryResponse.Results.headerRegionUri(result, StringView))))
                print(results_str, ",data_source_name=", repr(String(C.DiscoveryResponse.Results.dataSourceName(result, StringView))))
                print(results_str, ",driver_instance_id=", repr(String(C.DiscoveryResponse.Results.driverInstanceId(result, StringView))))
                print(results_str, ",driver_control_channel=", repr(String(C.DiscoveryResponse.Results.driverControlChannel(result, StringView))))
                print(results_str, '}')
            end
            print(results_str, ']')
            log_message!(tap.io, ctx, "discovery", "DiscoveryResponse", (
                template_id = template_id,
                schema_id = schema_id,
                block_length = block_len,
                version = version,
                request_id = C.DiscoveryResponse.requestId(msg),
                status = C.DiscoveryResponse.status(msg),
                results = RawValue(String(take!(results_str))),
                error_message = String(C.DiscoveryResponse.errorMessage(msg, StringView)),
            ); flush_logs = tap.flush_logs)
            return true
        else
            log_message!(tap.io, ctx, "discovery", "Unknown", (
                template_id = template_id,
                schema_id = schema_id,
                block_length = block_len,
                version = version,
                buffer_len = length(buffer),
            ); flush_logs = tap.flush_logs)
            return true
        end
    catch err
        log_decode_error!(tap, ctx, "discovery", template_id, err)
        return true
    end
end

function handle_tracelink_message!(tap::TapState, ctx::TapHandlerState, buffer::AbstractVector{UInt8})
    length(buffer) < C.TRACELINK_MESSAGE_HEADER_LEN && return false
    header = C.TraceLinkMessageHeader.Decoder(buffer, 0)
    if C.TraceLinkMessageHeader.schemaId(header) !=
       C.TraceLinkMessageHeader.sbe_schema_id(C.TraceLinkMessageHeader.Decoder)
        return false
    end
    if C.TraceLinkMessageHeader.version(header) !=
       C.TraceLinkMessageHeader.sbe_schema_version(C.TraceLinkMessageHeader.Decoder)
        return false
    end
    template_id = C.TraceLinkMessageHeader.templateId(header)
    schema_id = C.TraceLinkMessageHeader.schemaId(header)
    block_len = C.TraceLinkMessageHeader.blockLength(header)
    version = C.TraceLinkMessageHeader.version(header)

    try
        if template_id == C.TraceLinkSet.sbe_template_id(C.TraceLinkSet.Decoder)
            C.TraceLinkSet.wrap!(tap.decoders.tracelink_set, buffer, 0; header = header)
            msg = tap.decoders.tracelink_set
            parents = C.TraceLinkSet.parents(msg)
            buf = IOBuffer()
            print(buf, '[')
            first = true
            for parent in parents
                first || print(buf, ',')
                first = false
                print(buf, C.TraceLinkSet.Parents.traceId(parent))
            end
            print(buf, ']')
            log_message!(tap.io, ctx, "tracelink", "TraceLinkSet", (
                template_id = template_id,
                schema_id = schema_id,
                block_length = block_len,
                version = version,
                msg_stream_id = C.TraceLinkSet.streamId(msg),
                epoch = C.TraceLinkSet.epoch(msg),
                seq = C.TraceLinkSet.seq(msg),
                trace_id = C.TraceLinkSet.traceId(msg),
                parents = RawValue(String(take!(buf))),
            ); flush_logs = tap.flush_logs)
            return true
        else
            log_message!(tap.io, ctx, "tracelink", "Unknown", (
                template_id = template_id,
                schema_id = schema_id,
                block_length = block_len,
                version = version,
                buffer_len = length(buffer),
            ); flush_logs = tap.flush_logs)
            return true
        end
    catch err
        log_decode_error!(tap, ctx, "tracelink", template_id, err)
        return true
    end
end

function handle_bridge_message!(tap::TapState, ctx::TapHandlerState, buffer::AbstractVector{UInt8})
    length(buffer) < C.BRIDGE_MESSAGE_HEADER_LEN && return false
    header = C.BridgeMessageHeader.Decoder(buffer, 0)
    if C.BridgeMessageHeader.schemaId(header) !=
       C.BridgeMessageHeader.sbe_schema_id(C.BridgeMessageHeader.Decoder)
        return false
    end
    if C.BridgeMessageHeader.version(header) !=
       C.BridgeMessageHeader.sbe_schema_version(C.BridgeMessageHeader.Decoder)
        return false
    end
    template_id = C.BridgeMessageHeader.templateId(header)
    schema_id = C.BridgeMessageHeader.schemaId(header)
    block_len = C.BridgeMessageHeader.blockLength(header)
    version = C.BridgeMessageHeader.version(header)

    try
        if template_id == C.TEMPLATE_BRIDGE_FRAME_CHUNK
            C.BridgeFrameChunk.wrap!(tap.decoders.bridge_chunk, buffer, 0; header = header)
            msg = tap.decoders.bridge_chunk
            log_message!(tap.io, ctx, "bridge", "BridgeFrameChunk", (
                template_id = template_id,
                schema_id = schema_id,
                block_length = block_len,
                version = version,
                msg_stream_id = C.BridgeFrameChunk.streamId(msg),
                epoch = C.BridgeFrameChunk.epoch(msg),
                seq = C.BridgeFrameChunk.seq(msg),
                trace_id = C.BridgeFrameChunk.traceId(msg),
                chunk_index = C.BridgeFrameChunk.chunkIndex(msg),
                chunk_count = C.BridgeFrameChunk.chunkCount(msg),
                chunk_offset = C.BridgeFrameChunk.chunkOffset(msg),
                chunk_length = C.BridgeFrameChunk.chunkLength(msg),
                payload_length = C.BridgeFrameChunk.payloadLength(msg),
                payload_crc32c = C.BridgeFrameChunk.payloadCrc32c_in_acting_version(msg) ?
                    C.BridgeFrameChunk.payloadCrc32c(msg) : UInt32(0),
                header_included = C.BridgeFrameChunk.headerIncluded(msg),
                header_bytes_len = C.BridgeFrameChunk.headerBytes_length(msg),
                payload_bytes_len = C.BridgeFrameChunk.payloadBytes_length(msg),
            ); flush_logs = tap.flush_logs)
            return true
        else
            log_message!(tap.io, ctx, "bridge", "Unknown", (
                template_id = template_id,
                schema_id = schema_id,
                block_length = block_len,
                version = version,
                buffer_len = length(buffer),
            ); flush_logs = tap.flush_logs)
            return true
        end
    catch err
        log_decode_error!(tap, ctx, "bridge", template_id, err)
        return true
    end
end

function handle_tap_fragment!(tap::TapState, ctx::TapHandlerState, buffer::AbstractVector{UInt8})
    if handle_driver_message!(tap, ctx, buffer)
        return nothing
    end
    if handle_discovery_message!(tap, ctx, buffer)
        return nothing
    end
    if handle_tracelink_message!(tap, ctx, buffer)
        return nothing
    end
    if handle_bridge_message!(tap, ctx, buffer)
        return nothing
    end
    if handle_control_message!(tap, ctx, buffer)
        return nothing
    end
    log_message!(tap.io, ctx, "unknown", "Unknown", (
        buffer_len = length(buffer),
    ); flush_logs = tap.flush_logs)
    return nothing
end

function add_subscription!(subs::Vector{TapSubscription}, client::AeronTensorPool.AbstractTensorPoolClient, tap::TapState, label::String, channel::String, stream_id::Int32, seen::Set{Tuple{String, Int32}})
    stream_id == 0 && return nothing
    key = (channel, stream_id)
    key in seen && return nothing
    push!(seen, key)
    subscription = Aeron.add_subscription(AeronTensorPool.aeron_client(client), channel, stream_id)
    ctx = TapHandlerState(tap, label, channel, stream_id)
    assembler = Aeron.FragmentAssembler(Aeron.FragmentHandler(ctx) do st, buffer, _
        handle_tap_fragment!(st.tap, st, buffer)
        nothing
    end)
    push!(subs, TapSubscription(label, channel, stream_id, subscription, assembler))
    return nothing
end

function parse_extra_sub(value::String)
    parts = split(value, ',')
    length(parts) < 2 && error("--extra-sub requires channel,stream_id[,label]")
    channel = parts[1]
    stream_id = parse(Int32, parts[2])
    label = length(parts) >= 3 ? parts[3] : "extra"
    return (label, channel, stream_id)
end

function usage()
    println("Usage: julia --project scripts/aeron_tap.jl <driver_config> [--log <path>] [--duration <sec>]")
    println("       [--data-channel <uri>] [--descriptor-stream-id <id>] [--metadata-stream-id <id>]")
    println("       [--extra-sub channel,stream_id,label] [--flush]")
    println("Env: TP_TAP_FLUSH=1 or TAP_FLUSH=1")
end

function build_tap_subscriptions(client::AeronTensorPool.AbstractTensorPoolClient, tap::TapState, driver_cfg::DriverConfig; data_channel::String, descriptor_stream_id::Int32, metadata_stream_id::Int32, extra_subs = [])
    subs = TapSubscription[]
    seen = Set{Tuple{String, Int32}}()

    add_subscription!(subs, client, tap, "driver-control", driver_cfg.endpoints.control_channel, driver_cfg.endpoints.control_stream_id, seen)
    add_subscription!(subs, client, tap, "announce", driver_cfg.endpoints.announce_channel, driver_cfg.endpoints.announce_stream_id, seen)
    add_subscription!(subs, client, tap, "driver-qos", driver_cfg.endpoints.qos_channel, driver_cfg.endpoints.qos_stream_id, seen)

    add_subscription!(subs, client, tap, "control", data_channel, driver_cfg.endpoints.control_stream_id, seen)
    add_subscription!(subs, client, tap, "descriptor", data_channel, descriptor_stream_id, seen)
    add_subscription!(subs, client, tap, "qos", data_channel, driver_cfg.endpoints.qos_stream_id, seen)
    add_subscription!(subs, client, tap, "metadata", data_channel, metadata_stream_id, seen)

    for (label, channel, stream_id) in extra_subs
        add_subscription!(subs, client, tap, label, channel, stream_id, seen)
    end

    return subs
end

function parse_args(args::Vector{String})
    isempty(args) && return nothing
    cfg_path = args[1]
    log_path = ""
    data_channel = ""
    descriptor_stream_id = Int32(0)
    metadata_stream_id = Int32(0)
    duration_s = 0.0
    flush_logs = get(ENV, "TP_TAP_FLUSH", get(ENV, "TAP_FLUSH", "0")) == "1"
    extra_subs = Tuple{String, String, Int32}[]

    i = 2
    while i <= length(args)
        arg = args[i]
        if arg == "--log" && i < length(args)
            log_path = args[i + 1]
            i += 1
        elseif arg == "--data-channel" && i < length(args)
            data_channel = args[i + 1]
            i += 1
        elseif arg == "--descriptor-stream-id" && i < length(args)
            descriptor_stream_id = parse(Int32, args[i + 1])
            i += 1
        elseif arg == "--metadata-stream-id" && i < length(args)
            metadata_stream_id = parse(Int32, args[i + 1])
            i += 1
        elseif arg == "--duration" && i < length(args)
            duration_s = parse(Float64, args[i + 1])
            i += 1
        elseif arg == "--extra-sub" && i < length(args)
            push!(extra_subs, parse_extra_sub(args[i + 1]))
            i += 1
        elseif arg == "--flush"
            flush_logs = true
        elseif arg == "--help" || arg == "-h"
            return nothing
        else
            error("unknown argument: $(arg)")
        end
        i += 1
    end
    return (cfg_path, log_path, data_channel, descriptor_stream_id, metadata_stream_id, duration_s, flush_logs, extra_subs)
end

function run_tap(cfg_path::String, log_path::String, data_channel::String, descriptor_stream_id::Int32, metadata_stream_id::Int32, duration_s::Float64, flush_logs::Bool, extra_subs)
    driver_cfg = from_toml(DriverConfig, cfg_path; env = true)
    default_cfg = default_producer_config()
    data_channel = isempty(data_channel) ? driver_cfg.endpoints.control_channel : data_channel
    descriptor_stream_id = descriptor_stream_id == 0 ? default_cfg.descriptor_stream_id : descriptor_stream_id
    metadata_stream_id = metadata_stream_id == 0 ? default_cfg.metadata_stream_id : metadata_stream_id

    aeron_dir = get(ENV, "AERON_DIR", driver_cfg.endpoints.aeron_dir)
    ctx = TensorPoolContext(driver_cfg.endpoints; aeron_dir = aeron_dir)
    client = connect(ctx)

    io = isempty(log_path) ? stdout : open(log_path, "w")
    flush_logs = flush_logs || (!isempty(log_path))
    tap_state = TapState(io, flush_logs, TapDecoders())
    subs = build_tap_subscriptions(client, tap_state, driver_cfg; data_channel = data_channel, descriptor_stream_id = descriptor_stream_id, metadata_stream_id = metadata_stream_id, extra_subs = extra_subs)
    agent = TapAgent(tap_state, subs, AeronTensorPool.Control.DEFAULT_FRAGMENT_LIMIT)
    composite = CompositeAgent(agent)
    runner = AgentRunner(BackoffIdleStrategy(), composite)

    @info "Aeron tap started" data_channel descriptor_stream_id metadata_stream_id log_path

    try
        if duration_s > 0
            start = time()
            Agent.start_on_thread(runner)
            while time() - start < duration_s
                sleep(0.1)
            end
            close(runner)
            wait(runner)
        else
            Agent.start_on_thread(runner)
            wait(runner)
        end
    finally
        try
            close(runner)
        catch
        end
        close(client)
        io !== stdout && close(io)
    end
end

function main(args::Vector{String})
    parsed = parse_args(args)
    parsed === nothing && return usage()
    cfg_path, log_path, data_channel, descriptor_stream_id, metadata_stream_id, duration_s, flush_logs, extra_subs = parsed
    try
        run_tap(cfg_path, log_path, data_channel, descriptor_stream_id, metadata_stream_id, duration_s, flush_logs, extra_subs)
    catch err
        report_script_error(err) || rethrow()
    end
    return nothing
end

main(ARGS)
