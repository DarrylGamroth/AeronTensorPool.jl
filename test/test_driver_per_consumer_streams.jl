using Test

@testset "Driver per-consumer stream allocation" begin
    with_driver_and_client() do driver, client
        base_dir = mktempdir()
        endpoints = DriverEndpoints(
            "driver-test",
            Aeron.MediaDriver.aeron_dir(driver),
            "aeron:ipc",
            1000,
            "aeron:ipc",
            1001,
            "aeron:ipc",
            1200,
        )
        shm = DriverShmConfig(base_dir, false, UInt32(4096), "660", [base_dir])
        policies = DriverPolicyConfig(false, "raw", UInt32(100), UInt32(10_000), UInt32(3), false, false, UInt32(2000), "")
        profile = DriverProfileConfig(
            "raw",
            UInt32(8),
            UInt16(256),
            UInt8(8),
            [DriverPoolConfig(UInt16(1), UInt32(1024))],
        )
        streams = Dict("cam1" => DriverStreamConfig("cam1", UInt32(1001), "raw"))
        cfg = DriverConfig(
            endpoints,
            shm,
            policies,
            Dict("raw" => profile),
            streams;
            descriptor_stream_id_range = AeronTensorPool.DriverStreamIdRange(UInt32(2000), UInt32(2002)),
            control_stream_id_range = AeronTensorPool.DriverStreamIdRange(UInt32(2100), UInt32(2102)),
        )

        driver_state = init_driver(cfg; client = client)

        pub = Aeron.add_publication(client, "aeron:ipc", 1000)
        sub_responses = Aeron.add_subscription(client, "aeron:ipc", 1000)
        sub_configs = Aeron.add_subscription(client, "aeron:ipc", 1000)

        attach_proxy = AttachRequestProxy(pub)
        poller = DriverResponsePoller(sub_responses)

        correlation_id = Int64(1)
        sent = send_attach!(
            attach_proxy;
            correlation_id = correlation_id,
            stream_id = UInt32(1001),
            client_id = UInt32(7),
            role = DriverRole.CONSUMER,
            publish_mode = DriverPublishMode.REQUIRE_EXISTING,
        )
        @test sent == true

        ok = wait_for() do
            driver_do_work!(driver_state)
            poll_driver_responses!(poller)
            attach = poller.last_attach
            attach !== nothing && attach.correlation_id == correlation_id
        end
        @test ok == true

        hello_len = AeronTensorPool.MESSAGE_HEADER_LEN +
            Int(ConsumerHello.sbe_block_length(ConsumerHello.Decoder)) +
            Int(ConsumerHello.descriptorChannel_header_length) +
            sizeof("aeron:ipc") +
            Int(ConsumerHello.controlChannel_header_length) +
            sizeof("aeron:ipc")
        hello_encoder = ConsumerHello.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1})
        sent = with_claimed_buffer!(pub, Aeron.BufferClaim(), hello_len) do buf
            ConsumerHello.wrap_and_apply_header!(hello_encoder, buf, 0)
            ConsumerHello.streamId!(hello_encoder, UInt32(1001))
            ConsumerHello.consumerId!(hello_encoder, UInt32(7))
            ConsumerHello.supportsShm!(
                hello_encoder,
                AeronTensorPool.ShmTensorpoolControl.Bool_.TRUE,
            )
            ConsumerHello.supportsProgress!(
                hello_encoder,
                AeronTensorPool.ShmTensorpoolControl.Bool_.FALSE,
            )
            ConsumerHello.mode!(hello_encoder, Mode.STREAM)
            ConsumerHello.maxRateHz!(hello_encoder, UInt16(0))
            ConsumerHello.expectedLayoutVersion!(hello_encoder, UInt32(1))
            ConsumerHello.progressIntervalUs!(hello_encoder, typemax(UInt32))
            ConsumerHello.progressBytesDelta!(hello_encoder, typemax(UInt32))
            ConsumerHello.progressMajorDeltaUnits!(hello_encoder, typemax(UInt32))
            ConsumerHello.descriptorStreamId!(hello_encoder, UInt32(1))
            ConsumerHello.controlStreamId!(hello_encoder, UInt32(2))
            ConsumerHello.descriptorChannel!(hello_encoder, "aeron:ipc")
            ConsumerHello.controlChannel!(hello_encoder, "aeron:ipc")
        end
        @test sent == true

        config_decoder = ConsumerConfigMsg.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
        assigned_descriptor = Ref{UInt32}(0)
        assigned_control = Ref{UInt32}(0)
        assigned = Ref(false)
        handler = Aeron.FragmentHandler(nothing) do _, buffer, _
            header = MessageHeader.Decoder(buffer, 0)
            if MessageHeader.templateId(header) == AeronTensorPool.TEMPLATE_CONSUMER_CONFIG
                ConsumerConfigMsg.wrap!(config_decoder, buffer, 0; header = header)
                assigned_descriptor[] = ConsumerConfigMsg.descriptorStreamId(config_decoder)
                assigned_control[] = ConsumerConfigMsg.controlStreamId(config_decoder)
                assigned[] = true
            end
            nothing
        end
        assembler = Aeron.FragmentAssembler(handler)

        got_config = wait_for() do
            driver_do_work!(driver_state)
            Aeron.poll(sub_configs, assembler, Int32(AeronTensorPool.DEFAULT_FRAGMENT_LIMIT))
            assigned[]
        end
        @test got_config == true
        @test assigned_descriptor[] != 0
        @test assigned_control[] != 0

        close_driver_state!(driver_state)
        close(pub)
        close(sub_responses)
        close(sub_configs)
    end
end

@testset "Driver per-consumer stream decline on empty ranges" begin
    with_driver_and_client() do driver, client
        base_dir = mktempdir()
        endpoints = DriverEndpoints(
            "driver-test",
            Aeron.MediaDriver.aeron_dir(driver),
            "aeron:ipc",
            1000,
            "aeron:ipc",
            1001,
            "aeron:ipc",
            1200,
        )
        shm = DriverShmConfig(base_dir, false, UInt32(4096), "660", [base_dir])
        policies = DriverPolicyConfig(false, "raw", UInt32(100), UInt32(10_000), UInt32(3), false, false, UInt32(2000), "")
        profile = DriverProfileConfig(
            "raw",
            UInt32(8),
            UInt16(256),
            UInt8(8),
            [DriverPoolConfig(UInt16(1), UInt32(1024))],
        )
        streams = Dict("cam1" => DriverStreamConfig("cam1", UInt32(1001), "raw"))
        cfg = DriverConfig(
            endpoints,
            shm,
            policies,
            Dict("raw" => profile),
            streams;
            descriptor_stream_id_range = nothing,
            control_stream_id_range = nothing,
        )

        driver_state = init_driver(cfg; client = client)

        pub = Aeron.add_publication(client, "aeron:ipc", 1000)
        sub_responses = Aeron.add_subscription(client, "aeron:ipc", 1000)
        sub_configs = Aeron.add_subscription(client, "aeron:ipc", 1000)

        attach_proxy = AttachRequestProxy(pub)
        poller = DriverResponsePoller(sub_responses)

        correlation_id = Int64(1)
        sent = send_attach!(
            attach_proxy;
            correlation_id = correlation_id,
            stream_id = UInt32(1001),
            client_id = UInt32(9),
            role = DriverRole.CONSUMER,
            publish_mode = DriverPublishMode.REQUIRE_EXISTING,
        )
        @test sent == true

        ok = wait_for() do
            driver_do_work!(driver_state)
            poll_driver_responses!(poller)
            attach = poller.last_attach
            attach !== nothing && attach.correlation_id == correlation_id
        end
        @test ok == true

        hello_len = AeronTensorPool.MESSAGE_HEADER_LEN +
            Int(ConsumerHello.sbe_block_length(ConsumerHello.Decoder)) +
            Int(ConsumerHello.descriptorChannel_header_length) +
            sizeof("aeron:ipc") +
            Int(ConsumerHello.controlChannel_header_length) +
            sizeof("aeron:ipc")
        hello_encoder = ConsumerHello.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1})
        sent = with_claimed_buffer!(pub, Aeron.BufferClaim(), hello_len) do buf
            ConsumerHello.wrap_and_apply_header!(hello_encoder, buf, 0)
            ConsumerHello.streamId!(hello_encoder, UInt32(1001))
            ConsumerHello.consumerId!(hello_encoder, UInt32(9))
            ConsumerHello.supportsShm!(
                hello_encoder,
                AeronTensorPool.ShmTensorpoolControl.Bool_.TRUE,
            )
            ConsumerHello.supportsProgress!(
                hello_encoder,
                AeronTensorPool.ShmTensorpoolControl.Bool_.FALSE,
            )
            ConsumerHello.mode!(hello_encoder, Mode.STREAM)
            ConsumerHello.maxRateHz!(hello_encoder, UInt16(0))
            ConsumerHello.expectedLayoutVersion!(hello_encoder, UInt32(1))
            ConsumerHello.progressIntervalUs!(hello_encoder, typemax(UInt32))
            ConsumerHello.progressBytesDelta!(hello_encoder, typemax(UInt32))
            ConsumerHello.progressMajorDeltaUnits!(hello_encoder, typemax(UInt32))
            ConsumerHello.descriptorStreamId!(hello_encoder, UInt32(1))
            ConsumerHello.controlStreamId!(hello_encoder, UInt32(2))
            ConsumerHello.descriptorChannel!(hello_encoder, "aeron:ipc")
            ConsumerHello.controlChannel!(hello_encoder, "aeron:ipc")
        end
        @test sent == true

        config_decoder = ConsumerConfigMsg.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
        assigned_descriptor = Ref{UInt32}(0)
        assigned_control = Ref{UInt32}(0)
        assigned = Ref(false)
        handler = Aeron.FragmentHandler(nothing) do _, buffer, _
            header = MessageHeader.Decoder(buffer, 0)
            if MessageHeader.templateId(header) == AeronTensorPool.TEMPLATE_CONSUMER_CONFIG
                ConsumerConfigMsg.wrap!(config_decoder, buffer, 0; header = header)
                assigned_descriptor[] = ConsumerConfigMsg.descriptorStreamId(config_decoder)
                assigned_control[] = ConsumerConfigMsg.controlStreamId(config_decoder)
                assigned[] = true
            end
            nothing
        end
        assembler = Aeron.FragmentAssembler(handler)

        got_config = wait_for() do
            driver_do_work!(driver_state)
            Aeron.poll(sub_configs, assembler, Int32(AeronTensorPool.DEFAULT_FRAGMENT_LIMIT))
            assigned[]
        end
        @test got_config == true
        @test assigned_descriptor[] == UInt32(0)
        @test assigned_control[] == UInt32(0)

        close_driver_state!(driver_state)
        close(pub)
        close(sub_responses)
        close(sub_configs)
    end
end
