using Test

@testset "Driver attach existing_or_create creates stream" begin
    with_driver_and_client() do media_driver, client
        base_dir = mktempdir()

        endpoints = AeronTensorPool.DriverEndpoints(
            "driver-dynamic",
            Aeron.MediaDriver.aeron_dir(media_driver),
            "aeron:ipc",
            16000,
            "aeron:ipc",
            16001,
            "aeron:ipc",
            16002,
        )
        shm = AeronTensorPool.DriverShmConfig(base_dir, "default", false, UInt32(4096), "660", [base_dir])
        policies = AeronTensorPool.DriverPolicyConfig(
            true,
            "raw",
            UInt32(100),
            UInt32(10_000),
            UInt32(3),
            false,
            false,
            false,
            false,
            UInt32(2000),
            "",
        )
        profile = AeronTensorPool.DriverProfileConfig(
            "raw",
            UInt32(8),
            UInt16(256),
            UInt8(8),
            [AeronTensorPool.DriverPoolConfig(UInt16(1), UInt32(1024))],
        )
        cfg = AeronTensorPool.DriverConfig(
            endpoints,
            shm,
            policies,
            Dict("raw" => profile),
            Dict{String, AeronTensorPool.DriverStreamConfig}();
            stream_id_range = AeronTensorPool.DriverStreamIdRange(UInt32(9000), UInt32(9001)),
        )

        driver_state = AeronTensorPool.init_driver(cfg; client = client)

        pub = Aeron.add_publication(client, endpoints.control_channel, endpoints.control_stream_id)
        sub = Aeron.add_subscription(client, endpoints.control_channel, endpoints.control_stream_id)
        attach_proxy = AeronTensorPool.AttachRequestProxy(pub)
        poller = AeronTensorPool.DriverResponsePoller(sub)

        correlation_id = Int64(1)
        requested_stream = UInt32(9000)
        sent = AeronTensorPool.send_attach!(
            attach_proxy;
            correlation_id = correlation_id,
            stream_id = requested_stream,
            client_id = UInt32(7),
            role = AeronTensorPool.DriverRole.CONSUMER,
            publish_mode = AeronTensorPool.DriverPublishMode.EXISTING_OR_CREATE,
        )
        @test sent == true

        ok = wait_for() do
            AeronTensorPool.driver_do_work!(driver_state)
            AeronTensorPool.poll_driver_responses!(poller)
            attach = poller.last_attach
            attach !== nothing && attach.correlation_id == correlation_id
        end
        @test ok == true
        attach = poller.last_attach
        @test attach !== nothing
        @test attach.code == AeronTensorPool.DriverResponseCode.OK
        @test attach.stream_id == requested_stream
        @test !isempty(view(attach.header_region_uri))
        @test attach.pool_count > 0

        header_uri = view(attach.header_region_uri)
        header_path = AeronTensorPool.parse_shm_uri(header_uri).path
        @test isfile(header_path)

        pool_uri = view(attach.pools[1].region_uri)
        pool_path = AeronTensorPool.parse_shm_uri(pool_uri).path
        @test isfile(pool_path)

        close(pub)
        close(sub)
        close_driver_state!(driver_state)
    end
end
