using UnsafeArrays

@testset "Aeron integration handlers" begin
    with_driver_and_client() do driver, client
        control_stream = Int32(12001)
        descriptor_stream = Int32(12002)
        qos_stream = Int32(12003)
        uri = "aeron:ipc"

        consumer_cfg = ConsumerSettings(
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
            "",
            String[],
            false,
            UInt32(250),
            UInt32(65536),
            UInt32(0),
            UInt64(1_000_000_000),
            UInt64(1_000_000_000),
            UInt64(3_000_000_000),
            "",
            UInt32(0),
            "",
            UInt32(0),
        )
        consumer_state = init_consumer(consumer_cfg; client = client)
        ctrl_asm = make_control_assembler(consumer_state)
        desc_asm = make_descriptor_assembler(consumer_state)

        pub_control = Aeron.add_publication(client, uri, control_stream)
        pub_descriptor = Aeron.add_publication(client, uri, descriptor_stream)
        try

        claim = Aeron.BufferClaim()
        cfg_len = AeronTensorPool.MESSAGE_HEADER_LEN +
            Int(ConsumerConfigMsg.sbe_block_length(ConsumerConfigMsg.Decoder)) +
            Int(ConsumerConfigMsg.payloadFallbackUri_header_length) +
            Int(ConsumerConfigMsg.descriptorChannel_header_length) +
            Int(ConsumerConfigMsg.controlChannel_header_length)
        sent_cfg = AeronTensorPool.with_claimed_buffer!(pub_control, claim, cfg_len) do buf
            enc = ConsumerConfigMsg.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1})
            ConsumerConfigMsg.wrap_and_apply_header!(enc, buf, 0)
            ConsumerConfigMsg.streamId!(enc, consumer_state.config.stream_id)
            ConsumerConfigMsg.consumerId!(enc, consumer_state.config.consumer_id)
            ConsumerConfigMsg.useShm!(enc, AeronTensorPool.ShmTensorpoolControl.Bool_.TRUE)
            ConsumerConfigMsg.mode!(enc, Mode.LATEST)
            ConsumerConfigMsg.decimation!(enc, UInt16(1))
            ConsumerConfigMsg.descriptorStreamId!(
                enc,
                ConsumerConfigMsg.descriptorStreamId_null_value(ConsumerConfigMsg.Encoder),
            )
            ConsumerConfigMsg.controlStreamId!(
                enc,
                ConsumerConfigMsg.controlStreamId_null_value(ConsumerConfigMsg.Encoder),
            )
            ConsumerConfigMsg.payloadFallbackUri_length!(enc, 0)
            ConsumerConfigMsg.descriptorChannel_length!(enc, 0)
            ConsumerConfigMsg.controlChannel_length!(enc, 0)
        end
        @test sent_cfg

        ok = wait_for() do
            Aeron.poll(
                consumer_state.runtime.control.sub_control,
                ctrl_asm,
                AeronTensorPool.DEFAULT_FRAGMENT_LIMIT,
            ) > 0
        end
        @test ok
        @test consumer_state.config.use_shm == true
        @test consumer_state.config.mode == Mode.LATEST

        sent_desc = AeronTensorPool.with_claimed_buffer!(pub_descriptor, claim, AeronTensorPool.FRAME_DESCRIPTOR_LEN) do buf
            enc = FrameDescriptor.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1})
            FrameDescriptor.wrap_and_apply_header!(enc, buf, 0)
            FrameDescriptor.streamId!(enc, consumer_state.config.stream_id)
            FrameDescriptor.epoch!(enc, UInt64(1))
            FrameDescriptor.seq!(enc, UInt64(1))
            FrameDescriptor.headerIndex!(enc, UInt32(0))
            FrameDescriptor.timestampNs!(enc, UInt64(0))
            FrameDescriptor.metaVersion!(enc, UInt32(1))
        end
        @test sent_desc
        ok_desc = wait_for() do
            Aeron.poll(consumer_state.runtime.sub_descriptor, desc_asm, AeronTensorPool.DEFAULT_FRAGMENT_LIMIT) > 0
        end
        @test ok_desc
        finally
            try
                close(pub_control)
                close(pub_descriptor)
            catch
            end
            close_consumer_state!(consumer_state)
        end
    end
end
