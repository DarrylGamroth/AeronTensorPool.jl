using Test

@testset "RateLimiter end-to-end" begin
    with_driver_and_client() do media_driver, client
        base_dir = mktempdir()

        endpoints = DriverEndpoints(
            "rate-limiter-test",
            Aeron.MediaDriver.aeron_dir(media_driver),
            "aeron:ipc",
            1000,
            "aeron:ipc",
            1100,
            "aeron:ipc",
            1200,
        )
        shm = DriverShmConfig(base_dir, "default", false, UInt32(4096), "660", [base_dir])
        policies = DriverPolicyConfig(false, "raw", UInt32(100), UInt32(10_000), UInt32(3), false, false, false, false, UInt32(2000), "")
        profile = DriverProfileConfig(
            "raw",
            UInt32(8),
            UInt16(256),
            UInt8(8),
            [DriverPoolConfig(UInt16(1), UInt32(1024))],
        )
        streams = Dict(
            "src" => DriverStreamConfig("src", UInt32(10001), "raw"),
            "dest" => DriverStreamConfig("dest", UInt32(10002), "raw"),
        )
        cfg = DriverConfig(
            endpoints,
            shm,
            policies,
            Dict("raw" => profile),
            streams,
        )

        driver_state = init_driver(cfg; client = client)

        producer_client = init_driver_client(
            client,
            endpoints.control_channel,
            endpoints.control_stream_id,
            UInt32(1),
            DriverRole.PRODUCER;
            keepalive_interval_ns = UInt64(1_000_000_000),
        )
        corr_prod = send_attach_request!(
            producer_client;
            stream_id = UInt32(10001),
            expected_layout_version = UInt32(1),
            publish_mode = DriverPublishMode.REQUIRE_EXISTING,
        )
        attach_prod_ref = Ref{Union{AttachResponse, Nothing}}(nothing)
        ok_attach_prod = wait_for() do
            driver_do_work!(driver_state)
            attach = AeronTensorPool.Control.poll_attach!(producer_client, corr_prod, UInt64(time_ns()))
            if attach !== nothing
                attach_prod_ref[] = attach
                return true
            end
            return false
        end
        @test ok_attach_prod == true
        attach_prod = attach_prod_ref[]
        @test attach_prod !== nothing

        prod_cfg = default_producer_config(;
            aeron_dir = endpoints.aeron_dir,
            aeron_uri = "aeron:ipc",
            stream_id = UInt32(10001),
            producer_id = UInt32(1),
            descriptor_stream_id = Int32(1100),
            control_stream_id = endpoints.control_stream_id,
            qos_stream_id = endpoints.qos_stream_id,
            metadata_stream_id = Int32(1300),
        )
        producer_state = Producer.init_producer_from_attach(
            prod_cfg,
            attach_prod;
            driver_client = producer_client,
            client = client,
        )
        prod_ctrl = Producer.make_control_assembler(producer_state)
        prod_qos = Producer.make_qos_assembler(producer_state)

        consumer_client = init_driver_client(
            client,
            endpoints.control_channel,
            endpoints.control_stream_id,
            UInt32(2),
            DriverRole.CONSUMER;
            keepalive_interval_ns = UInt64(1_000_000_000),
        )
        corr_cons = send_attach_request!(
            consumer_client;
            stream_id = UInt32(10002),
            expected_layout_version = UInt32(1),
            publish_mode = DriverPublishMode.REQUIRE_EXISTING,
        )
        attach_cons_ref = Ref{Union{AttachResponse, Nothing}}(nothing)
        ok_attach_cons = wait_for() do
            driver_do_work!(driver_state)
            attach = AeronTensorPool.Control.poll_attach!(consumer_client, corr_cons, UInt64(time_ns()))
            if attach !== nothing
                attach_cons_ref[] = attach
                return true
            end
            return false
        end
        @test ok_attach_cons == true
        attach_cons = attach_cons_ref[]
        @test attach_cons !== nothing

        frame_count = Ref(0)
        consumer_cfg = default_consumer_config(;
            aeron_dir = endpoints.aeron_dir,
            aeron_uri = "aeron:ipc",
            stream_id = UInt32(10002),
            consumer_id = UInt32(2),
            shm_base_dir = base_dir,
            descriptor_stream_id = Int32(1100),
            control_stream_id = endpoints.control_stream_id,
            qos_stream_id = endpoints.qos_stream_id,
            max_rate_hz = UInt16(1),
        )
        consumer_state = Consumer.init_consumer_from_attach(
            consumer_cfg,
            attach_cons;
            driver_client = consumer_client,
            client = client,
        )
        callbacks = ConsumerCallbacks(; on_frame! = (st, view) -> (frame_count[] += 1))
        cons_desc = Consumer.make_descriptor_assembler(consumer_state; callbacks = callbacks)
        cons_ctrl = Consumer.make_control_assembler(consumer_state)

        rl_cfg = RateLimiterConfig(
            "rate-limiter-01",
            endpoints.aeron_dir,
            "aeron:ipc",
            base_dir,
            endpoints.control_channel,
            endpoints.control_stream_id,
            "aeron:ipc",
            Int32(1100),
            "aeron:ipc",
            endpoints.control_stream_id,
            "aeron:ipc",
            endpoints.qos_stream_id,
            "aeron:ipc",
            Int32(1300),
            false,
            false,
            false,
            UInt32(1),
            Int32(0),
            Int32(0),
            Int32(0),
            Int32(0),
            UInt64(1_000_000_000),
            UInt64(5_000_000_000),
            UInt64(1_000_000_000),
        )
        mapping = RateLimiterMapping(UInt32(10001), UInt32(10002), "raw", UInt32(10002), UInt32(1))
        rl_state = init_rate_limiter(rl_cfg, [mapping]; client = client, driver_work_fn = () -> driver_do_work!(driver_state))
        @test rl_state.mappings[1].max_rate_hz == UInt32(1)

        payload = UInt8[1, 2, 3, 4]
        shape = Int32[4]
        strides = Int32[1]
        sent = 0

        start = time()
        while time() - start < 1.0
            Producer.producer_do_work!(producer_state, prod_ctrl, prod_qos)
            Consumer.consumer_do_work!(consumer_state, cons_desc, cons_ctrl)
            rate_limiter_do_work!(rl_state)
            if sent < 10
                Producer.offer_frame!(producer_state, payload, shape, strides, Dtype.UINT8, UInt32(0))
                sent += 1
            end
            yield()
        end

        @test rl_state.mappings[1].max_rate_hz == UInt32(1)
        @test frame_count[] > 0
        @test frame_count[] < sent

        close_producer_state!(producer_state)
        close_consumer_state!(consumer_state)
        close_driver_state!(driver_state)
    end
end
