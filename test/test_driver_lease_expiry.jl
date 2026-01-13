using Test

@testset "Driver lease expiry" begin
    with_driver_and_client() do media_driver, client
        base_dir = mktempdir()

            endpoints = DriverEndpoints(
                "driver-test",
                Aeron.MediaDriver.aeron_dir(media_driver),
                "aeron:ipc",
                13200,
                "aeron:ipc",
                13201,
                "aeron:ipc",
                13202,
            )
            shm = DriverShmConfig(base_dir, "default", false, UInt32(4096), "660", [base_dir])
            policies = DriverPolicyConfig(false, "raw", UInt32(1000), UInt32(10), UInt32(1), false, false, false, false, UInt32(2000), "")
            profile = DriverProfileConfig(
                "raw",
                UInt32(8),
                UInt16(256),
                UInt8(8),
                [DriverPoolConfig(UInt16(1), UInt32(4096))],
            )
            streams = Dict("cam1" => DriverStreamConfig("cam1", UInt32(55), "raw"))
            cfg = DriverConfig(
                endpoints,
                shm,
                policies,
                Dict("raw" => profile),
                streams,
            )

            driver_state = init_driver(cfg; client = client)

            pub = Aeron.add_publication(client, "aeron:ipc", 13200)
            sub = Aeron.add_subscription(client, "aeron:ipc", 13200)

            attach_proxy = AttachRequestProxy(pub)
            poller = DriverResponsePoller(sub)

            correlation_id = Int64(1)
            sent = send_attach!(
                attach_proxy;
                correlation_id = correlation_id,
                stream_id = UInt32(55),
                client_id = UInt32(99),
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
            attach = poller.last_attach
            @test attach !== nothing
            @test attach.code == DriverResponseCode.OK
            lease_id = attach.lease_id

            sleep(0.05)
            ok = wait_for() do
                driver_do_work!(driver_state)
                poll_driver_responses!(poller)
                revoke = poller.last_revoke
                revoke !== nothing && revoke.lease_id == lease_id
            end
            @test ok == true
            revoke = poller.last_revoke
            @test revoke !== nothing
            @test revoke.reason == DriverLeaseRevokeReason.EXPIRED

        close_driver_state!(driver_state)
        close(pub)
        close(sub)
    end
end
