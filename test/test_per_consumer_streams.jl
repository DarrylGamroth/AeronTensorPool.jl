@testset "Per-consumer descriptor/control streams" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            aeron_dir = Aeron.MediaDriver.aeron_dir(driver)
            header_uri = "shm:file?path=$(joinpath(dir, "tp_header"))"
            pool_uri = "shm:file?path=$(joinpath(dir, "tp_pool"))"
            producer_cfg = ProducerConfig(
                aeron_dir,
                "aeron:ipc",
                Int32(1300),
                Int32(1301),
                Int32(1302),
                Int32(1303),
                UInt32(7),
                UInt32(77),
                UInt32(1),
                UInt32(8),
                dir,
                "tensorpool",
                "pc-test",
                header_uri,
                PayloadPoolConfig[PayloadPoolConfig(UInt16(1), pool_uri, UInt32(4096), UInt32(8))],
                UInt8(MAX_DIMS),
                UInt64(1_000_000_000),
                UInt64(1_000_000_000),
                UInt64(250_000),
                UInt64(65536),
            )

            consumer_cfg = ConsumerSettings(
                aeron_dir,
                "aeron:ipc",
                Int32(1300),
                Int32(1301),
                Int32(1302),
                UInt32(7),
                UInt32(17),
                UInt32(1),
                UInt8(MAX_DIMS),
                Mode.STREAM,
                UInt16(1),
                UInt32(0),
                true,
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
                "aeron:ipc",
                UInt32(2300),
                "aeron:ipc",
                UInt32(2301),
            )

            producer_state = init_producer(producer_cfg; client = client)
            consumer_state = init_consumer(consumer_cfg; client = client)
            prod_ctrl = make_control_assembler(producer_state)
            cons_ctrl = make_control_assembler(consumer_state)
            cons_desc = make_descriptor_assembler(consumer_state)
            fragment_limit = AeronTensorPool.DEFAULT_FRAGMENT_LIMIT

            assigned = wait_for() do
                emit_consumer_hello!(consumer_state)
                Aeron.poll(producer_state.runtime.control.sub_control, prod_ctrl, fragment_limit)
                Aeron.poll(consumer_state.runtime.control.sub_control, cons_ctrl, fragment_limit)
                consumer_state.assigned_descriptor_stream_id == UInt32(2300) &&
                    consumer_state.assigned_control_stream_id == UInt32(2301) &&
                    consumer_state.runtime.sub_progress !== nothing
            end
            @test assigned

            mapped = wait_for() do
                emit_announce!(producer_state)
                Aeron.poll(consumer_state.runtime.control.sub_control, cons_ctrl, fragment_limit)
                consumer_state.mappings.header_mmap !== nothing
            end
            @test mapped

            payload = UInt8[1, 2, 3, 4]
            shape = Int32[4]
            strides = Int32[1]
            published = wait_for() do
                offer_frame!(producer_state, payload, shape, strides, Dtype.UINT8, UInt32(1))
            end
            @test published

            got_frame = wait_for() do
                Aeron.poll(consumer_state.runtime.sub_descriptor, cons_desc, fragment_limit)
                consumer_state.metrics.frames_ok > 0
            end
            @test got_frame

            close_consumer_state!(consumer_state)
            close_producer_state!(producer_state)
        end
    end
end

@testset "Per-consumer stream validation and QoS liveness" begin
    entry = AeronTensorPool.ProducerConsumerStream(
        nothing,
        nothing,
        "",
        "",
        UInt32(0),
        UInt32(0),
        UInt16(0),
        UInt64(0),
        UInt64(0),
        UInt64(10),
    )
    @test AeronTensorPool.consumer_stream_last_seen_ns(entry) == UInt64(10)

    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            aeron_dir = Aeron.MediaDriver.aeron_dir(driver)
            message_header_len = AeronTensorPool.MESSAGE_HEADER_LEN
            ConsumerHello = AeronTensorPool.ConsumerHello
            header_uri = "shm:file?path=$(joinpath(dir, "tp_header_invalid"))"
            pool_uri = "shm:file?path=$(joinpath(dir, "tp_pool_invalid"))"

            producer_cfg = ProducerConfig(
                aeron_dir,
                "aeron:ipc",
                Int32(1310),
                Int32(1311),
                Int32(1312),
                Int32(1313),
                UInt32(9),
                UInt32(79),
                UInt32(1),
                UInt32(8),
                dir,
                "tensorpool",
                "pc-invalid",
                header_uri,
                PayloadPoolConfig[PayloadPoolConfig(UInt16(1), pool_uri, UInt32(4096), UInt32(8))],
                UInt8(MAX_DIMS),
                UInt64(1_000_000_000),
                UInt64(1_000_000_000),
                UInt64(250_000),
                UInt64(65536),
            )

            consumer_cfg = ConsumerSettings(
                aeron_dir,
                "aeron:ipc",
                Int32(1310),
                Int32(1311),
                Int32(1312),
                UInt32(9),
                UInt32(18),
                UInt32(1),
                UInt8(MAX_DIMS),
                Mode.STREAM,
                UInt16(1),
                UInt32(0),
                true,
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

            producer_state = init_producer(producer_cfg; client = client)
            consumer_state = init_consumer(consumer_cfg; client = client)
            prod_ctrl = make_control_assembler(producer_state)
            cons_ctrl = make_control_assembler(consumer_state)
            fragment_limit = AeronTensorPool.DEFAULT_FRAGMENT_LIMIT

            invalid_len = message_header_len +
                Int(ConsumerHello.sbe_block_length(ConsumerHello.Decoder)) +
                Int(ConsumerHello.descriptorChannel_header_length) +
                sizeof("aeron:ipc") +
                Int(ConsumerHello.controlChannel_header_length) +
                sizeof("aeron:ipc")

            invalid_sent = wait_for() do
                with_claimed_buffer!(consumer_state.runtime.control.pub_control, consumer_state.runtime.hello_claim, invalid_len) do buf
                    ConsumerHello.wrap_and_apply_header!(consumer_state.runtime.hello_encoder, buf, 0)
                    ConsumerHello.streamId!(consumer_state.runtime.hello_encoder, consumer_state.config.stream_id)
                    ConsumerHello.consumerId!(consumer_state.runtime.hello_encoder, consumer_state.config.consumer_id)
                    ConsumerHello.supportsShm!(
                        consumer_state.runtime.hello_encoder,
                        AeronTensorPool.ShmTensorpoolControl.Bool_.TRUE,
                    )
                    ConsumerHello.supportsProgress!(
                        consumer_state.runtime.hello_encoder,
                        AeronTensorPool.ShmTensorpoolControl.Bool_.FALSE,
                    )
                    ConsumerHello.mode!(consumer_state.runtime.hello_encoder, consumer_state.config.mode)
                    ConsumerHello.maxRateHz!(consumer_state.runtime.hello_encoder, UInt16(0))
                    ConsumerHello.expectedLayoutVersion!(consumer_state.runtime.hello_encoder, consumer_state.config.expected_layout_version)
                    ConsumerHello.progressIntervalUs!(consumer_state.runtime.hello_encoder, typemax(UInt32))
                    ConsumerHello.progressBytesDelta!(consumer_state.runtime.hello_encoder, typemax(UInt32))
                    ConsumerHello.progressRowsDelta!(consumer_state.runtime.hello_encoder, typemax(UInt32))
                    ConsumerHello.descriptorStreamId!(
                        consumer_state.runtime.hello_encoder,
                        ConsumerHello.descriptorStreamId_null_value(ConsumerHello.Encoder),
                    )
                    ConsumerHello.controlStreamId!(
                        consumer_state.runtime.hello_encoder,
                        ConsumerHello.controlStreamId_null_value(ConsumerHello.Encoder),
                    )
                    ConsumerHello.descriptorChannel!(consumer_state.runtime.hello_encoder, "aeron:ipc")
                    ConsumerHello.controlChannel!(consumer_state.runtime.hello_encoder, "aeron:ipc")
                end
            end
            @test invalid_sent

            declined = wait_for() do
                Aeron.poll(producer_state.runtime.control.sub_control, prod_ctrl, fragment_limit)
                Aeron.poll(consumer_state.runtime.control.sub_control, cons_ctrl, fragment_limit)
                consumer_state.assigned_descriptor_stream_id == UInt32(0) &&
                    consumer_state.assigned_control_stream_id == UInt32(0)
            end
            @test declined

            close_consumer_state!(consumer_state)
            close_producer_state!(producer_state)
        end
    end
end
