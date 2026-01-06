using Test

@testset "Attach retry with stale response" begin
    with_driver_and_client() do media_driver, client
        base_dir = mktempdir()

        endpoints = DriverEndpoints(
            "driver-test",
            Aeron.MediaDriver.aeron_dir(media_driver),
            "aeron:ipc",
            13310,
            "aeron:ipc",
            13311,
            "aeron:ipc",
            13312,
        )
        shm = DriverShmConfig(base_dir, false, UInt32(4096), "660", [base_dir])
        policies = DriverPolicies(false, "raw", UInt32(100), UInt32(100), UInt32(2), false, false, UInt32(2000), "")
        profile = DriverProfileConfig(
            "raw",
            UInt32(8),
            UInt16(256),
            UInt8(8),
            [DriverPoolConfig(UInt16(1), UInt32(4096))],
        )
        streams = Dict("cam1" => DriverStreamConfig("cam1", UInt32(56), "raw"))
        cfg = DriverConfig(endpoints, shm, policies, Dict("raw" => profile), streams)
        driver_state = init_driver(cfg; client = client)

        driver_client = init_driver_client(
            client,
            "aeron:ipc",
            Int32(13310),
            UInt32(40),
            DriverRole.CONSUMER,
            attach_purge_interval_ns = UInt64(5_000_000_000),
        )

        cid1 = send_attach_request!(driver_client; stream_id = UInt32(56))
        @test cid1 != 0
        ok = wait_for() do
            driver_do_work!(driver_state)
            driver_client_do_work!(driver_client, UInt64(time_ns()))
            haskey(driver_client.poller.attach_by_correlation, cid1)
        end
        @test ok

        cid2 = send_attach_request!(driver_client; stream_id = UInt32(56))
        @test cid2 != 0
        ok = wait_for() do
            driver_do_work!(driver_state)
            driver_client_do_work!(driver_client, UInt64(time_ns()))
            haskey(driver_client.poller.attach_by_correlation, cid2)
        end
        @test ok

        attach2 = AeronTensorPool.Control.poll_attach!(driver_client, cid2, UInt64(time_ns()))
        @test attach2 !== nothing
        @test attach2.correlation_id == cid2
        @test haskey(driver_client.poller.attach_by_correlation, cid1)

        close_driver_state!(driver_state)
    end
end
