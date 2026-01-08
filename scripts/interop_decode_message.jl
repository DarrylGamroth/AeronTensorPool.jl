#!/usr/bin/env julia
using AeronTensorPool
using AeronTensorPool.ShmTensorpoolControl
using AeronTensorPool.ShmTensorpoolDriver
using StringViews: StringView

function usage()
    println("Usage: julia --project scripts/interop_decode_message.jl <file|hex:...>")
end

function read_buffer(arg::String)
    if startswith(arg, "hex:")
        hex = arg[5:end]
        length(hex) % 2 == 0 || error("hex string length must be even")
        bytes = Vector{UInt8}(undef, length(hex) ÷ 2)
        for i in 1:2:length(hex)
            bytes[(i + 1) ÷ 2] = parse(UInt8, hex[i:i + 1], base = 16)
        end
        return bytes
    end
    return read(arg)
end

function print_pools(msg::ShmTensorpoolControl.ShmPoolAnnounce.Decoder)
    pools = ShmTensorpoolControl.ShmPoolAnnounce.payloadPools(msg)
    count = ShmTensorpoolControl.ShmPoolAnnounce.PayloadPools.count(pools)
    println("payload_pools=$count")
    for i in 1:count
        pool = ShmTensorpoolControl.ShmPoolAnnounce.PayloadPools.next!(pools)
        pool_id = ShmTensorpoolControl.ShmPoolAnnounce.PayloadPools.poolId(pool)
        stride = ShmTensorpoolControl.ShmPoolAnnounce.PayloadPools.strideBytes(pool)
        uri = String(ShmTensorpoolControl.ShmPoolAnnounce.PayloadPools.uri(pool, StringView))
        println("  pool_id=$pool_id stride_bytes=$stride uri=$uri")
    end
end

function print_pools(msg::ShmTensorpoolDriver.ShmAttachResponse.Decoder)
    pools = ShmTensorpoolDriver.ShmAttachResponse.payloadPools(msg)
    count = ShmTensorpoolDriver.ShmAttachResponse.PayloadPools.count(pools)
    println("payload_pools=$count")
    for i in 1:count
        pool = ShmTensorpoolDriver.ShmAttachResponse.PayloadPools.next!(pools)
        pool_id = ShmTensorpoolDriver.ShmAttachResponse.PayloadPools.poolId(pool)
        stride = ShmTensorpoolDriver.ShmAttachResponse.PayloadPools.strideBytes(pool)
        uri = String(ShmTensorpoolDriver.ShmAttachResponse.PayloadPools.uri(pool, StringView))
        println("  pool_id=$pool_id stride_bytes=$stride uri=$uri")
    end
end

function main()
    if length(ARGS) < 1
        usage()
        return 1
    end
    buffer = read_buffer(ARGS[1])

    header = ShmTensorpoolControl.MessageHeader.Decoder(buffer, 0)
    schema_id = ShmTensorpoolControl.MessageHeader.schemaId(header)
    template_id = ShmTensorpoolControl.MessageHeader.templateId(header)
    version = ShmTensorpoolControl.MessageHeader.version(header)
    block_length = ShmTensorpoolControl.MessageHeader.blockLength(header)

    println("schema_id=$schema_id template_id=$template_id version=$version block_length=$block_length")

    if schema_id == ShmTensorpoolControl.MessageHeader.schemaId(ShmTensorpoolControl.MessageHeader.Decoder)
        announce_tid = ShmTensorpoolControl.ShmPoolAnnounce.sbe_template_id(ShmTensorpoolControl.ShmPoolAnnounce.Decoder)
        if template_id == announce_tid
            msg = ShmTensorpoolControl.ShmPoolAnnounce.Decoder(buffer)
            ShmTensorpoolControl.ShmPoolAnnounce.wrap!(msg, buffer, 0)
            println("message=ShmPoolAnnounce")
            println("stream_id=$(ShmTensorpoolControl.ShmPoolAnnounce.streamId(msg))")
            println("producer_id=$(ShmTensorpoolControl.ShmPoolAnnounce.producerId(msg))")
            println("epoch=$(ShmTensorpoolControl.ShmPoolAnnounce.epoch(msg))")
            println("layout_version=$(ShmTensorpoolControl.ShmPoolAnnounce.layoutVersion(msg))")
            println("header_nslots=$(ShmTensorpoolControl.ShmPoolAnnounce.headerNslots(msg))")
            println("header_slot_bytes=$(ShmTensorpoolControl.ShmPoolAnnounce.headerSlotBytes(msg))")
            uri = String(ShmTensorpoolControl.ShmPoolAnnounce.headerRegionUri(msg, StringView))
            println("header_uri=$uri")
            print_pools(msg)
            return 0
        end
    elseif schema_id == ShmTensorpoolDriver.MessageHeader.schemaId(ShmTensorpoolDriver.MessageHeader.Decoder)
        response_tid =
            ShmTensorpoolDriver.ShmAttachResponse.sbe_template_id(ShmTensorpoolDriver.ShmAttachResponse.Decoder)
        if template_id == response_tid
            msg = ShmTensorpoolDriver.ShmAttachResponse.Decoder(buffer)
            ShmTensorpoolDriver.ShmAttachResponse.wrap!(msg, buffer, 0)
            println("message=ShmAttachResponse")
            println("correlation_id=$(ShmTensorpoolDriver.ShmAttachResponse.correlationId(msg))")
            println("code=$(ShmTensorpoolDriver.ShmAttachResponse.code(msg))")
            println("lease_id=$(ShmTensorpoolDriver.ShmAttachResponse.leaseId(msg))")
            println("stream_id=$(ShmTensorpoolDriver.ShmAttachResponse.streamId(msg))")
            println("epoch=$(ShmTensorpoolDriver.ShmAttachResponse.epoch(msg))")
            println("layout_version=$(ShmTensorpoolDriver.ShmAttachResponse.layoutVersion(msg))")
            println("header_nslots=$(ShmTensorpoolDriver.ShmAttachResponse.headerNslots(msg))")
            println("header_slot_bytes=$(ShmTensorpoolDriver.ShmAttachResponse.headerSlotBytes(msg))")
            uri = String(ShmTensorpoolDriver.ShmAttachResponse.headerRegionUri(msg, StringView))
            println("header_uri=$uri")
            print_pools(msg)
            return 0
        end
    end

    println("message=Unknown")
    return 2
end

main()
