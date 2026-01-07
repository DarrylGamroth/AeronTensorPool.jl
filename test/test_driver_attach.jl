using Test

@testset "Driver attach/detach" begin
    with_driver_and_client() do media_driver, client
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
                streams,
            )

            driver_state = init_driver(cfg; client = client)

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
                attach = poller.last_attach
                attach !== nothing && attach.correlation_id == correlation_id
            end
            @test ok == true
            attach = poller.last_attach
            @test attach !== nothing
            @test attach.code == DriverResponseCode.OK
            @test attach.stream_id == UInt32(1001)
            @test attach.lease_id != ShmAttachResponse.leaseId_null_value(ShmAttachResponse.Decoder)
            @test attach.epoch != ShmAttachResponse.epoch_null_value(ShmAttachResponse.Decoder)
            @test attach.layout_version != ShmAttachResponse.layoutVersion_null_value(ShmAttachResponse.Decoder)
            @test attach.header_nslots != ShmAttachResponse.headerNslots_null_value(ShmAttachResponse.Decoder)
            @test attach.header_slot_bytes == UInt16(HEADER_SLOT_BYTES)
            @test attach.max_dims == UInt8(MAX_DIMS)
            @test !isempty(view(attach.header_region_uri))
            @test attach.pool_count > 0
            producer_lease_id = attach.lease_id

            header_uri = view(attach.header_region_uri)
            header_path = parse_shm_uri(header_uri).path
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
                attach = poller.last_attach
                attach !== nothing && attach.correlation_id == dup_id
            end
            @test ok == true
            attach = poller.last_attach
            @test attach !== nothing
            @test attach.code == DriverResponseCode.REJECTED

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
                attach = poller.last_attach
                attach !== nothing && attach.correlation_id == missing_id
            end
            @test ok == true
            attach = poller.last_attach
            @test attach !== nothing
            @test attach.code == DriverResponseCode.REJECTED

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
                attach = poller.last_attach
                attach !== nothing && attach.correlation_id == huge_id
            end
            @test ok == true
            attach = poller.last_attach
            @test attach !== nothing
            @test attach.code == DriverResponseCode.REJECTED

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
                detach = poller.last_detach
                detach !== nothing && detach.correlation_id == detach_id
            end
            @test ok == true
            detach = poller.last_detach
            @test detach !== nothing
            @test detach.code == DriverResponseCode.OK

        close_driver_state!(driver_state)
        close(pub)
        close(sub)
    end
end
