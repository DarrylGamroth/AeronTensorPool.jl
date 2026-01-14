using Test

const BridgeBool = AeronTensorPool.BridgeBool
const BridgeFrameChunk = AeronTensorPool.BridgeFrameChunk
const ShmTensorpoolBridge = AeronTensorPool.ShmTensorpoolBridge

function encode_bridge_chunk!(
    buf::Vector{UInt8},
    stream_id::UInt32,
    epoch::UInt64,
    seq::UInt64,
    trace_id::UInt64,
    chunk_index::UInt32,
    chunk_count::UInt32,
    chunk_offset::UInt32,
    chunk_length::UInt32,
    payload_length::UInt32,
    header_bytes::Union{Nothing, Vector{UInt8}},
    payload_bytes::Vector{UInt8},
)
    enc = BridgeFrameChunk.Encoder(Vector{UInt8})
    BridgeFrameChunk.wrap_and_apply_header!(enc, buf, 0)
    BridgeFrameChunk.streamId!(enc, stream_id)
    BridgeFrameChunk.epoch!(enc, epoch)
    BridgeFrameChunk.seq!(enc, seq)
    BridgeFrameChunk.traceId!(enc, trace_id)
    BridgeFrameChunk.chunkIndex!(enc, chunk_index)
    BridgeFrameChunk.chunkCount!(enc, chunk_count)
    BridgeFrameChunk.chunkOffset!(enc, chunk_offset)
    BridgeFrameChunk.chunkLength!(enc, chunk_length)
    BridgeFrameChunk.payloadLength!(enc, payload_length)
    BridgeFrameChunk.headerIncluded!(enc, header_bytes === nothing ? BridgeBool.FALSE : BridgeBool.TRUE)
    if header_bytes === nothing
        BridgeFrameChunk.headerBytes!(enc, nothing)
    else
        BridgeFrameChunk.headerBytes!(enc, header_bytes)
    end
    BridgeFrameChunk.payloadBytes!(enc, payload_bytes)
    return nothing
end

function make_bridge_receiver_with_producer(driver, client; stream_id::UInt32)
    mktempdir("/dev/shm") do dir
        base = joinpath(dir, "dst")
        mkpath(base)
        prepare_canonical_shm_layout(
            base;
            namespace = "tensorpool",
            stream_id = stream_id,
            epoch = 1,
            pool_id = 1,
        )
        header_uri = canonical_header_uri(base, "tensorpool", stream_id, 1)
        pool_uri = canonical_pool_uri(base, "tensorpool", stream_id, 1, 1)

        pool = PayloadPoolConfig(UInt16(1), pool_uri, UInt32(4096), UInt32(8))
        producer_cfg = ProducerConfig(
            Aeron.MediaDriver.aeron_dir(driver),
            "aeron:ipc",
            Int32(17310),
            Int32(17311),
            Int32(17312),
            Int32(17313),
            stream_id,
            UInt32(110),
            UInt32(1),
            UInt32(8),
            base,
            "tensorpool",
            "bridge-tracelink",
            header_uri,
            [pool],
            UInt8(MAX_DIMS),
            UInt64(1_000_000_000),
            UInt64(1_000_000_000),
            UInt64(250_000),
            UInt64(65536),
            false,
        )

        producer_state = Producer.init_producer(producer_cfg; client = client)
        mapping = BridgeMapping(stream_id, stream_id, "default", UInt32(0), Int32(0), Int32(0))
        bridge_cfg = BridgeConfig(
            "bridge-tracelink",
            Aeron.MediaDriver.aeron_dir(driver),
            "aeron:ipc",
            Int32(17320),
            "aeron:ipc",
            Int32(17321),
            "",
            Int32(0),
            Int32(0),
            UInt32(1408),
            UInt32(512),
            UInt32(1024),
            UInt32(2048),
            UInt64(1_000_000_000),
            false,
            false,
            false,
            false,
        )
        receiver = Bridge.init_bridge_receiver(bridge_cfg, mapping; producer_state = producer_state, client = client)
        receiver.have_announce = true
        receiver.source_info.stream_id = stream_id
        receiver.source_info.epoch = UInt64(1)
        receiver.source_info.layout_version = UInt32(1)
        receiver.source_info.pool_stride_bytes[UInt16(1)] = UInt32(4096)
        return receiver, producer_state
    end
end

@testset "Bridge traceId propagation from chunks" begin
    with_driver_and_client() do driver, client
        receiver, producer_state = make_bridge_receiver_with_producer(driver, client; stream_id = UInt32(21))
        try
            sub = Aeron.add_subscription(client, "aeron:ipc", Int32(17310))
            ok = wait_for(; timeout = 3.0) do
                Aeron.is_connected(producer_state.runtime.pub_descriptor) && Aeron.is_connected(sub)
            end
            @test ok

            payload = Vector{UInt8}(undef, 16)
            fill!(payload, 0x2a)
            dims = ntuple(i -> i == 1 ? Int32(16) : Int32(0), AeronTensorPool.MAX_DIMS)
            strides = ntuple(_ -> Int32(0), AeronTensorPool.MAX_DIMS)
            header_bytes = Vector{UInt8}(undef, HEADER_SLOT_BYTES)
            slot_enc = SlotHeaderMsg.Encoder(Vector{UInt8})
            tensor_enc = TensorHeaderMsg.Encoder(Vector{UInt8})
            SlotHeaderMsg.wrap!(slot_enc, header_bytes, 0)
            write_slot_header!(
                slot_enc,
                tensor_enc,
                UInt64(0),
                UInt32(1),
                UInt32(length(payload)),
                UInt32(0),
                UInt32(0),
                UInt16(1),
                Dtype.UINT8,
                MajorOrder.ROW,
                UInt8(1),
                AeronTensorPool.ProgressUnit.NONE,
                UInt32(0),
                collect(dims),
                collect(strides),
            )
            SlotHeaderMsg.seqCommit!(slot_enc, (UInt64(5) << 1) | 1)
            slot_dec = SlotHeaderMsg.Decoder(Vector{UInt8})
            tensor_dec = TensorHeaderMsg.Decoder(Vector{UInt8})
            wrap_slot_header!(slot_dec, header_bytes, 0)
            slot_header = AeronTensorPool.try_read_slot_header(slot_dec, tensor_dec)
            @test slot_header !== nothing
            slot_header = slot_header::SlotHeader

            msg_len = AeronTensorPool.Bridge.bridge_chunk_message_length(
                HEADER_SLOT_BYTES,
                length(payload),
            )
            buf = Vector{UInt8}(undef, msg_len)
            encode_bridge_chunk!(
                buf,
                UInt32(21),
                UInt64(1),
                UInt64(5),
                UInt64(0xBEEF),
                UInt32(0),
                UInt32(1),
                UInt32(0),
                UInt32(length(payload)),
                UInt32(length(payload)),
                header_bytes,
                payload,
            )
            msg_header = ShmTensorpoolBridge.MessageHeader.Decoder(buf, 0)
            dec = BridgeFrameChunk.Decoder(Vector{UInt8})
            BridgeFrameChunk.wrap!(dec, buf, 0; header = msg_header)
            @test receiver.have_announce
            @test BridgeFrameChunk.streamId(dec) == receiver.mapping.dest_stream_id
            @test BridgeFrameChunk.epoch(dec) == receiver.source_info.epoch
            @test BridgeFrameChunk.chunkCount(dec) == UInt32(1)
            @test BridgeFrameChunk.chunkIndex(dec) == UInt32(0)
            @test BridgeFrameChunk.payloadLength(dec) == UInt32(length(payload))
            @test BridgeFrameChunk.chunkLength(dec) == UInt32(length(payload))
            @test BridgeFrameChunk.headerIncluded(dec) == BridgeBool.TRUE
            @test seqlock_is_committed(slot_header.seq_commit)
            @test seqlock_sequence(slot_header.seq_commit) == BridgeFrameChunk.seq(dec)
            @test UInt32(slot_header.values_len_bytes) == UInt32(length(payload))
            @test slot_header.pool_id == UInt16(1)
            @test slot_header.tensor.ndims == UInt8(1)
            Bridge.bridge_receive_chunk!(receiver, dec, UInt64(time_ns()))
            @test receiver.metrics.chunks_dropped == 0
            @test receiver.assembly.trace_id == UInt64(0xBEEF)

            ok = Bridge.bridge_rematerialize!(receiver, slot_header, payload)
            @test ok

            received = Ref(false)
            trace_id = Ref(UInt64(0))
            desc_handler = Aeron.FragmentHandler(nothing) do _, buffer, _
                header = MessageHeader.Decoder(buffer, 0)
                MessageHeader.templateId(header) ==
                AeronTensorPool.TEMPLATE_FRAME_DESCRIPTOR || return nothing
                desc = FrameDescriptor.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
                FrameDescriptor.wrap!(desc, buffer, 0; header = header)
                trace_id[] = FrameDescriptor.traceId(desc)
                received[] = true
                return nothing
            end
            desc_asm = Aeron.FragmentAssembler(desc_handler)

            ok = wait_for(; timeout = 3.0) do
                Aeron.poll(sub, desc_asm, Int32(10))
                received[]
            end
            @test ok
            @test trace_id[] == UInt64(0xBEEF)
        finally
            close_producer_state!(producer_state)
        end
    end
end

@testset "Bridge traceId mismatch drops frame" begin
    with_driver_and_client() do driver, client
        receiver, producer_state = make_bridge_receiver_with_producer(driver, client; stream_id = UInt32(22))
        try
            payload = Vector{UInt8}(undef, 16)
            fill!(payload, 0x2a)
            chunk_a = payload[1:8]
            chunk_b = payload[9:16]

            dims = ntuple(i -> i == 1 ? Int32(16) : Int32(0), AeronTensorPool.MAX_DIMS)
            strides = ntuple(_ -> Int32(0), AeronTensorPool.MAX_DIMS)
            header_bytes = Vector{UInt8}(undef, HEADER_SLOT_BYTES)
            slot_enc = SlotHeaderMsg.Encoder(Vector{UInt8})
            tensor_enc = TensorHeaderMsg.Encoder(Vector{UInt8})
            SlotHeaderMsg.wrap!(slot_enc, header_bytes, 0)
            write_slot_header!(
                slot_enc,
                tensor_enc,
                UInt64(0),
                UInt32(1),
                UInt32(length(payload)),
                UInt32(0),
                UInt32(0),
                UInt16(1),
                Dtype.UINT8,
                MajorOrder.ROW,
                UInt8(1),
                AeronTensorPool.ProgressUnit.NONE,
                UInt32(0),
                collect(dims),
                collect(strides),
            )
            SlotHeaderMsg.seqCommit!(slot_enc, (UInt64(6) << 1) | 1)

            msg_len_a = AeronTensorPool.Bridge.bridge_chunk_message_length(
                HEADER_SLOT_BYTES,
                length(chunk_a),
            )
            buf_a = Vector{UInt8}(undef, msg_len_a)
            encode_bridge_chunk!(
                buf_a,
                UInt32(22),
                UInt64(1),
                UInt64(6),
                UInt64(0xAA),
                UInt32(0),
                UInt32(2),
                UInt32(0),
                UInt32(length(chunk_a)),
                UInt32(length(payload)),
                header_bytes,
                chunk_a,
            )

            msg_len_b = AeronTensorPool.Bridge.bridge_chunk_message_length(0, length(chunk_b))
            buf_b = Vector{UInt8}(undef, msg_len_b)
            encode_bridge_chunk!(
                buf_b,
                UInt32(22),
                UInt64(1),
                UInt64(6),
                UInt64(0xBB),
                UInt32(1),
                UInt32(2),
                UInt32(length(chunk_a)),
                UInt32(length(chunk_b)),
                UInt32(length(payload)),
                nothing,
                chunk_b,
            )

            header = ShmTensorpoolBridge.MessageHeader.Decoder(buf_a, 0)
            dec = BridgeFrameChunk.Decoder(Vector{UInt8})
            BridgeFrameChunk.wrap!(dec, buf_a, 0; header = header)
            Bridge.bridge_receive_chunk!(receiver, dec, UInt64(time_ns()))

            header = ShmTensorpoolBridge.MessageHeader.Decoder(buf_b, 0)
            BridgeFrameChunk.wrap!(dec, buf_b, 0; header = header)
            Bridge.bridge_receive_chunk!(receiver, dec, UInt64(time_ns()))

            @test receiver.assembly.seq == 0
            @test receiver.assembly.received_chunks == 0
            @test receiver.assembly.trace_id == UInt64(0)
        finally
            close_producer_state!(producer_state)
        end
    end
end

@testset "Bridge duplicate conflicting chunk drops frame" begin
    with_driver_and_client() do driver, client
        receiver, producer_state = make_bridge_receiver_with_producer(driver, client; stream_id = UInt32(23))
        try
            payload = Vector{UInt8}(undef, 16)
            fill!(payload, 0x2a)
            chunk_a = payload[1:8]
            chunk_conflict = fill!(similar(chunk_a), 0x7e)

            dims = ntuple(i -> i == 1 ? Int32(16) : Int32(0), AeronTensorPool.MAX_DIMS)
            strides = ntuple(_ -> Int32(0), AeronTensorPool.MAX_DIMS)
            header_bytes = Vector{UInt8}(undef, HEADER_SLOT_BYTES)
            slot_enc = SlotHeaderMsg.Encoder(Vector{UInt8})
            tensor_enc = TensorHeaderMsg.Encoder(Vector{UInt8})
            SlotHeaderMsg.wrap!(slot_enc, header_bytes, 0)
            write_slot_header!(
                slot_enc,
                tensor_enc,
                UInt64(0),
                UInt32(1),
                UInt32(length(payload)),
                UInt32(0),
                UInt32(0),
                UInt16(1),
                Dtype.UINT8,
                MajorOrder.ROW,
                UInt8(1),
                AeronTensorPool.ProgressUnit.NONE,
                UInt32(0),
                collect(dims),
                collect(strides),
            )
            SlotHeaderMsg.seqCommit!(slot_enc, (UInt64(7) << 1) | 1)

            msg_len = AeronTensorPool.Bridge.bridge_chunk_message_length(
                HEADER_SLOT_BYTES,
                length(chunk_a),
            )
            buf_a = Vector{UInt8}(undef, msg_len)
            encode_bridge_chunk!(
                buf_a,
                UInt32(23),
                UInt64(1),
                UInt64(7),
                UInt64(0),
                UInt32(0),
                UInt32(2),
                UInt32(0),
                UInt32(length(chunk_a)),
                UInt32(length(payload)),
                header_bytes,
                chunk_a,
            )

            buf_conflict = Vector{UInt8}(undef, msg_len)
            encode_bridge_chunk!(
                buf_conflict,
                UInt32(23),
                UInt64(1),
                UInt64(7),
                UInt64(0),
                UInt32(0),
                UInt32(2),
                UInt32(0),
                UInt32(length(chunk_conflict)),
                UInt32(length(payload)),
                header_bytes,
                chunk_conflict,
            )

            header = ShmTensorpoolBridge.MessageHeader.Decoder(buf_a, 0)
            dec = BridgeFrameChunk.Decoder(Vector{UInt8})
            BridgeFrameChunk.wrap!(dec, buf_a, 0; header = header)
            Bridge.bridge_receive_chunk!(receiver, dec, UInt64(time_ns()))
            @test receiver.assembly.seq == UInt64(7)
            @test receiver.assembly.received_chunks == UInt32(1)

            header = ShmTensorpoolBridge.MessageHeader.Decoder(buf_conflict, 0)
            BridgeFrameChunk.wrap!(dec, buf_conflict, 0; header = header)
            Bridge.bridge_receive_chunk!(receiver, dec, UInt64(time_ns()))

            @test receiver.assembly.seq == 0
            @test receiver.assembly.received_chunks == 0
        finally
            close_producer_state!(producer_state)
        end
    end
end
