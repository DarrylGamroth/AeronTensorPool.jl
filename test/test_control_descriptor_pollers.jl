using Test
using UnsafeArrays

function build_consumer_config_buf(;
    stream_id::UInt32 = UInt32(10000),
    consumer_id::UInt32 = UInt32(1),
)
    msg_len = AeronTensorPool.MESSAGE_HEADER_LEN +
        Int(ConsumerConfigMsg.sbe_block_length(ConsumerConfigMsg.Decoder)) +
        Int(ConsumerConfigMsg.payloadFallbackUri_header_length) +
        Int(ConsumerConfigMsg.descriptorChannel_header_length) +
        Int(ConsumerConfigMsg.controlChannel_header_length)
    buf = Vector{UInt8}(undef, msg_len)
    enc = ConsumerConfigMsg.Encoder(Vector{UInt8})
    ConsumerConfigMsg.wrap_and_apply_header!(enc, buf, 0)
    AeronTensorPool.encode_consumer_config!(
        enc,
        stream_id,
        consumer_id;
        use_shm = true,
        mode = Mode.STREAM,
        descriptor_stream_id = UInt32(0),
        control_stream_id = UInt32(0),
        payload_fallback_uri = "",
        descriptor_channel = "",
        control_channel = "",
    )
    return buf
end

function build_frame_progress_buf(;
    stream_id::UInt32 = UInt32(10000),
    epoch::UInt64 = UInt64(1),
    seq::UInt64 = UInt64(1),
    payload_bytes::UInt64 = UInt64(0),
)
    buf = Vector{UInt8}(undef, AeronTensorPool.FRAME_PROGRESS_LEN)
    enc = FrameProgress.Encoder(Vector{UInt8})
    FrameProgress.wrap_and_apply_header!(enc, buf, 0)
    FrameProgress.streamId!(enc, stream_id)
    FrameProgress.epoch!(enc, epoch)
    FrameProgress.seq!(enc, seq)
    FrameProgress.payloadBytesFilled!(enc, payload_bytes)
    FrameProgress.state!(enc, AeronTensorPool.ShmTensorpoolControl.FrameProgressState.COMPLETE)
    return buf
end

function build_tracelink_buf(;
    stream_id::UInt32 = UInt32(10000),
    epoch::UInt64 = UInt64(1),
    seq::UInt64 = UInt64(1),
    trace_id::UInt64 = UInt64(42),
    parents::AbstractVector{UInt64} = UInt64[UInt64(7)],
)
    parent_count = length(parents)
    msg_len = AeronTensorPool.TRACELINK_MESSAGE_HEADER_LEN +
        Int(TraceLinkSet.sbe_block_length(TraceLinkSet.Decoder)) +
        Int(TraceLinkSet.Parents.sbe_header_size(TraceLinkSet.Parents.Decoder)) +
        parent_count * Int(TraceLinkSet.Parents.sbe_block_length(TraceLinkSet.Parents.Decoder))
    buf = Vector{UInt8}(undef, msg_len)
    enc = TraceLinkSet.Encoder(Vector{UInt8})
    TraceLinkSet.wrap_and_apply_header!(enc, buf, 0)
    AeronTensorPool.encode_tracelink_set!(enc, stream_id, epoch, seq, trace_id, parents)
    return buf
end

@testset "Control pollers: descriptor/config/progress/tracelink" begin
    with_driver_and_client() do driver, client
        ctx = TensorPoolContext(control_channel = "aeron:ipc", control_stream_id = Int32(15500))
        tp_client = connect(ctx; aeron_client = client)

        called = Ref(false)
        desc_handler = (poller, dec) -> (called[] = FrameDescriptor.seq(dec) == UInt64(1))
        desc_poller = FrameDescriptorPoller(tp_client, "aeron:ipc", Int32(15501), desc_handler)
        buf, _ = build_frame_descriptor(seq = UInt64(1))
        unsafe_buf = UnsafeArrays.UnsafeArray{UInt8, 1}(pointer(buf), (length(buf),))
        @test AeronTensorPool.Control.handle_control_message!(desc_poller, unsafe_buf)
        @test called[]

        called[] = false
        header = MessageHeader.Encoder(buf)
        MessageHeader.schemaId!(header, UInt16(999))
        @test !AeronTensorPool.Control.handle_control_message!(desc_poller, unsafe_buf)
        @test !called[]

        MessageHeader.schemaId!(header, MessageHeader.sbe_schema_id(MessageHeader.Encoder))
        MessageHeader.version!(
            header,
            UInt16(FrameDescriptor.sbe_schema_version(FrameDescriptor.Decoder) + 1),
        )
        @test !AeronTensorPool.Control.handle_control_message!(desc_poller, unsafe_buf)
        @test !called[]
        close(desc_poller)

        config_called = Ref(false)
        config_handler = (poller, dec) -> (config_called[] = ConsumerConfigMsg.streamId(dec) == UInt32(10000))
        config_poller = ConsumerConfigPoller(tp_client, "aeron:ipc", Int32(15502), config_handler)
        config_buf = build_consumer_config_buf()
        config_unsafe = UnsafeArrays.UnsafeArray{UInt8, 1}(pointer(config_buf), (length(config_buf),))
        @test AeronTensorPool.Control.handle_control_message!(config_poller, config_unsafe)
        @test config_called[]

        config_called[] = false
        config_header = MessageHeader.Encoder(config_buf)
        MessageHeader.templateId!(config_header, UInt16(0))
        @test !AeronTensorPool.Control.handle_control_message!(config_poller, config_unsafe)
        @test !config_called[]
        close(config_poller)

        progress_called = Ref(false)
        progress_handler = (poller, dec) -> (progress_called[] = FrameProgress.seq(dec) == UInt64(1))
        progress_poller = FrameProgressPoller(tp_client, "aeron:ipc", Int32(15503), progress_handler)
        progress_buf = build_frame_progress_buf()
        progress_unsafe = UnsafeArrays.UnsafeArray{UInt8, 1}(pointer(progress_buf), (length(progress_buf),))
        @test AeronTensorPool.Control.handle_control_message!(progress_poller, progress_unsafe)
        @test progress_called[]

        progress_called[] = false
        progress_header = MessageHeader.Encoder(progress_buf)
        MessageHeader.schemaId!(progress_header, UInt16(999))
        @test !AeronTensorPool.Control.handle_control_message!(progress_poller, progress_unsafe)
        @test !progress_called[]

        rebind!(progress_poller, "aeron:ipc", Int32(15504))
        @test Aeron.stream_id(progress_poller.subscription) == Int32(15504)
        close(progress_poller)

        tracelink_called = Ref(false)
        tracelink_handler = (poller, dec) -> (tracelink_called[] = TraceLinkSet.seq(dec) == UInt64(1))
        tracelink_poller = TraceLinkPoller(tp_client, "aeron:ipc", Int32(15505), tracelink_handler)
        tracelink_buf = build_tracelink_buf()
        tracelink_unsafe = UnsafeArrays.UnsafeArray{UInt8, 1}(pointer(tracelink_buf), (length(tracelink_buf),))
        @test AeronTensorPool.Control.handle_control_message!(tracelink_poller, tracelink_unsafe)
        @test tracelink_called[]

        tracelink_called[] = false
        tracelink_header = TraceLinkMessageHeader.Encoder(tracelink_buf)
        TraceLinkMessageHeader.schemaId!(tracelink_header, UInt16(999))
        @test !AeronTensorPool.Control.handle_control_message!(tracelink_poller, tracelink_unsafe)
        @test !tracelink_called[]
        close(tracelink_poller)
    end
end
