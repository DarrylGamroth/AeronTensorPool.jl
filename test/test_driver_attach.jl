using Test

@testset "Driver attach/detach" begin
    with_embedded_driver() do media_driver
        with_client(; driver = media_driver) do client
            base_dir = mktempdir()

            endpoints = DriverEndpoints(
                "driver-test",
                Aeron.MediaDriver.aeron_dir(media_driver),
                "aeron:ipc",
                1000,
                "aeron:ipc",
                1001,
                "aeron:ipc",
                1200,
            )
            shm = DriverShmConfig(base_dir, false, UInt32(4096), "660", [base_dir])
            policies = DriverPolicies(true, "raw", UInt32(100), UInt32(100), UInt32(3))
            profile = DriverProfileConfig(
                "raw",
                UInt32(8),
                UInt16(256),
                UInt8(8),
                [DriverPoolConfig(UInt16(1), UInt32(1024))],
            )
            cfg = DriverConfig(
                endpoints,
                shm,
                policies,
                Dict("raw" => profile),
                Dict{String, DriverStreamConfig}(),
            )

            driver_state = init_driver(cfg)

            pub = Aeron.add_publication(client, "aeron:ipc", 1000)
            sub = Aeron.add_subscription(client, "aeron:ipc", 1000)

            attach_proxy = AttachRequestProxy(pub)
            detach_proxy = DetachRequestProxy(pub)
            poller = DriverResponsePoller(sub)

            correlation_id = Int64(1)
            sent = send_attach!(
                attach_proxy;
                correlation_id = correlation_id,
                stream_id = UInt32(1001),
                client_id = UInt32(7),
                role = DriverRole.PRODUCER,
                publish_mode = DriverPublishMode.EXISTING_OR_CREATE,
            )
            @test sent == true

            ok = wait_for() do
                driver_do_work!(driver_state)
                poll_driver_responses!(poller)
                poller.last_attach !== nothing &&
                    poller.last_attach.correlation_id == correlation_id
            end
            @test ok == true
            @test poller.last_attach.code == DriverResponseCode.OK
            @test poller.last_attach.stream_id == UInt32(1001)
            @test !isempty(poller.last_attach.header_region_uri)
            @test !isempty(poller.last_attach.pools)

            header_path = parse_shm_uri(poller.last_attach.header_region_uri).path
            @test isfile(header_path)

            detach_id = Int64(2)
            sent = send_detach!(
                detach_proxy;
                correlation_id = detach_id,
                lease_id = poller.last_attach.lease_id,
                stream_id = UInt32(1001),
                client_id = UInt32(7),
                role = DriverRole.PRODUCER,
            )
            @test sent == true

            ok = wait_for() do
                driver_do_work!(driver_state)
                poll_driver_responses!(poller)
                poller.last_detach !== nothing &&
                    poller.last_detach.correlation_id == detach_id
            end
            @test ok == true
            @test poller.last_detach.code == DriverResponseCode.OK

            close_driver_state!(driver_state)
            close(pub)
            close(sub)
        end
    end
end
