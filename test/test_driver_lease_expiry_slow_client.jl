using Test

@testset "Driver lease expiry with delayed polling" begin
    with_driver_and_client() do media_driver, client
        base_dir = mktempdir()

        endpoints = DriverEndpoints(
            "driver-test",
            Aeron.MediaDriver.aeron_dir(media_driver),
            "aeron:ipc",
            13340,
            "aeron:ipc",
            13341,
            "aeron:ipc",
            13342,
        )
        shm = DriverShmConfig(base_dir, "default", false, UInt32(4096), "660", [base_dir])
        policies = DriverPolicyConfig(false, "raw", UInt32(20), UInt32(10), UInt32(1), false, false, false, false, UInt32(2000), "")
        profile = DriverProfileConfig(
            "raw",
            UInt32(8),
            UInt16(256),
            UInt8(8),
            [DriverPoolConfig(UInt16(1), UInt32(4096))],
        )
        streams = Dict("cam1" => DriverStreamConfig("cam1", UInt32(58), "raw"))
        cfg = DriverConfig(endpoints, shm, policies, Dict("raw" => profile), streams)
        driver_state = init_driver(cfg; client = client)

        producer_client = init_driver_client(
            client,
            "aeron:ipc",
            Int32(13340),
            UInt32(60),
            DriverRole.PRODUCER;
            keepalive_interval_ns = UInt64(50_000_000),
        )

        cid = send_attach_request!(producer_client; stream_id = UInt32(58))
        @test cid != 0
        ok = wait_for() do
            driver_do_work!(driver_state)
            driver_client_do_work!(producer_client, UInt64(time_ns()))
            haskey(producer_client.poller.attach_by_correlation, cid)
        end
        @test ok
        prod_attach = AeronTensorPool.Control.poll_attach!(producer_client, cid, UInt64(time_ns()))
        @test prod_attach !== nothing

        producer_cfg = ProducerConfig(
            Aeron.MediaDriver.aeron_dir(media_driver),
            "aeron:ipc",
            Int32(14340),
            Int32(14341),
            Int32(14342),
            Int32(14343),
            UInt32(58),
            UInt32(7),
            UInt32(1),
            UInt32(8),
            base_dir,
            "tensorpool",
            "producer-test",
            "",
            PayloadPoolConfig[],
            UInt8(MAX_DIMS),
            UInt64(100_000_000),
            UInt64(100_000_000),
            UInt64(250_000),
            UInt64(65536),
            false,
        )
        producer_state = Producer.init_producer_from_attach(
            producer_cfg,
            prod_attach;
            driver_client = producer_client,
            client = client,
        )
        prod_ctrl = Producer.make_control_assembler(producer_state)
        prod_qos = Producer.make_qos_assembler(producer_state)

        old_lease = producer_client.lease_id
        expiry_deadline = time_ns() + 150_000_000
        while time_ns() < expiry_deadline
            driver_do_work!(driver_state)
            sleep(0.005)
        end

        ok = wait_for(; timeout = 5.0) do
            driver_do_work!(driver_state)
            Producer.producer_do_work!(producer_state, prod_ctrl; qos_assembler = prod_qos)
            producer_state.driver_active && producer_client.lease_id != 0 && producer_client.lease_id != old_lease
        end
        @test ok

        close_producer_state!(producer_state)
        close_driver_state!(driver_state)
    end
end
