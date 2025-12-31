@testset "Aeron integration handlers" begin
    with_embedded_driver() do driver
        control_stream = Int32(12001)
        descriptor_stream = Int32(12002)
        qos_stream = Int32(12003)
        uri = "aeron:ipc"

        consumer_cfg = ConsumerConfig(
            Aeron.MediaDriver.aeron_dir(driver),
            uri,
            descriptor_stream,
            control_stream,
            qos_stream,
            UInt32(7),
            UInt32(99),
            UInt32(1),
            UInt8(MAX_DIMS),
            Mode.STREAM,
            UInt16(1),
            UInt32(256),
            false,
            true,
            false,
            UInt16(0),
            "",
            false,
            UInt32(250),
            UInt32(65536),
            UInt32(0),
            UInt64(1_000_000_000),
            UInt64(1_000_000_000),
        )
        consumer_state = init_consumer(consumer_cfg)
        ctrl_asm = make_control_assembler(consumer_state)
        desc_asm = make_descriptor_assembler(consumer_state)

        pub_control = Aeron.add_publication(consumer_state.client, uri, control_stream)
        pub_descriptor = Aeron.add_publication(consumer_state.client, uri, descriptor_stream)

        claim = Aeron.BufferClaim()
        cfg_len = AeronTensorPool.MESSAGE_HEADER_LEN +
            Int(ConsumerConfigMsg.sbe_block_length(ConsumerConfigMsg.Decoder)) +
            Int(ConsumerConfigMsg.payloadFallbackUri_header_length)
        sent_cfg = AeronTensorPool.try_claim_sbe!(
            pub_control,
            claim,
            cfg_len,
            buf -> begin
                buf_view = unsafe_wrap(Vector{UInt8}, pointer(buf), length(buf))
                enc = ConsumerConfigMsg.Encoder(Vector{UInt8})
                ConsumerConfigMsg.wrap_and_apply_header!(enc, buf_view, 0)
                ConsumerConfigMsg.streamId!(enc, consumer_state.config.stream_id)
                ConsumerConfigMsg.consumerId!(enc, consumer_state.config.consumer_id)
                ConsumerConfigMsg.useShm!(enc, AeronTensorPool.ShmTensorpoolControl.Bool_.TRUE)
                ConsumerConfigMsg.mode!(enc, Mode.LATEST)
                ConsumerConfigMsg.decimation!(enc, UInt16(1))
                ConsumerConfigMsg.payloadFallbackUri_length!(enc, 0)
            end,
        )
        @test sent_cfg

        ok = wait_for() do
            Aeron.poll(consumer_state.sub_control, ctrl_asm, AeronTensorPool.DEFAULT_FRAGMENT_LIMIT) > 0
        end
        @test ok
        @test consumer_state.config.use_shm == true
        @test consumer_state.config.mode == Mode.LATEST

        sent_desc = AeronTensorPool.try_claim_sbe!(
            pub_descriptor,
            claim,
            AeronTensorPool.FRAME_DESCRIPTOR_LEN,
            buf -> begin
                buf_view = unsafe_wrap(Vector{UInt8}, pointer(buf), length(buf))
                enc = FrameDescriptor.Encoder(Vector{UInt8})
                FrameDescriptor.wrap_and_apply_header!(enc, buf_view, 0)
                FrameDescriptor.streamId!(enc, consumer_state.config.stream_id)
                FrameDescriptor.epoch!(enc, UInt64(1))
                FrameDescriptor.seq!(enc, UInt64(1))
                FrameDescriptor.headerIndex!(enc, UInt32(0))
                FrameDescriptor.timestampNs!(enc, UInt64(0))
                FrameDescriptor.metaVersion!(enc, UInt32(1))
            end,
        )
        @test sent_desc
        ok_desc = wait_for() do
            Aeron.poll(consumer_state.sub_descriptor, desc_asm, AeronTensorPool.DEFAULT_FRAGMENT_LIMIT) > 0
        end
        @test ok_desc
    end
end
