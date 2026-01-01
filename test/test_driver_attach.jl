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
            policies = DriverPolicies(false, "raw", UInt32(100), UInt32(10_000), UInt32(3))
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
                streams,
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
                publish_mode = DriverPublishMode.REQUIRE_EXISTING,
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
            producer_lease_id = poller.last_attach.lease_id

            header_path = parse_shm_uri(poller.last_attach.header_region_uri).path
            @test isfile(header_path)

            dup_id = Int64(3)
            sent = send_attach!(
                attach_proxy;
                correlation_id = dup_id,
                stream_id = UInt32(1001),
                client_id = UInt32(7),
                role = DriverRole.PRODUCER,
                publish_mode = DriverPublishMode.REQUIRE_EXISTING,
            )
            @test sent == true
            ok = wait_for() do
                driver_do_work!(driver_state)
                poll_driver_responses!(poller)
                poller.last_attach !== nothing &&
                    poller.last_attach.correlation_id == dup_id
            end
            @test ok == true
            @test poller.last_attach.code == DriverResponseCode.REJECTED

            missing_id = Int64(4)
            sent = send_attach!(
                attach_proxy;
                correlation_id = missing_id,
                stream_id = UInt32(2000),
                client_id = UInt32(8),
                role = DriverRole.CONSUMER,
                publish_mode = DriverPublishMode.REQUIRE_EXISTING,
            )
            @test sent == true
            ok = wait_for() do
                driver_do_work!(driver_state)
                poll_driver_responses!(poller)
                poller.last_attach !== nothing &&
                    poller.last_attach.correlation_id == missing_id
            end
            @test ok == true
            @test poller.last_attach.code == DriverResponseCode.REJECTED

            huge_id = Int64(5)
            sent = send_attach!(
                attach_proxy;
                correlation_id = huge_id,
                stream_id = UInt32(1001),
                client_id = UInt32(9),
                role = DriverRole.CONSUMER,
                publish_mode = DriverPublishMode.REQUIRE_EXISTING,
                require_hugepages = DriverHugepagesPolicy.HUGEPAGES,
            )
            @test sent == true
            ok = wait_for() do
                driver_do_work!(driver_state)
                poll_driver_responses!(poller)
                poller.last_attach !== nothing &&
                    poller.last_attach.correlation_id == huge_id
            end
            @test ok == true
            @test poller.last_attach.code == DriverResponseCode.REJECTED

            detach_id = Int64(2)
            sent = send_detach!(
                detach_proxy;
                correlation_id = detach_id,
                lease_id = producer_lease_id,
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
