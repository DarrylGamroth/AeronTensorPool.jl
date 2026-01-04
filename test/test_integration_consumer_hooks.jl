using Test

struct TestFrameHook
    count::Base.RefValue{Int}
end

function (hook::TestFrameHook)(::ConsumerState, ::ConsumerFrameView)
    hook.count[] += 1
    return nothing
end

@testset "Consumer hook integration" begin
    with_driver_and_client() do media_driver, client
        base_dir = mktempdir()

        endpoints = DriverEndpoints(
            "driver-test",
            Aeron.MediaDriver.aeron_dir(media_driver),
            "aeron:ipc",
            13000,
            "aeron:ipc",
            13001,
            "aeron:ipc",
            13002,
        )
        shm = DriverShmConfig(base_dir, false, UInt32(4096), "660", [base_dir])
        policies = DriverPolicies(false, "raw", UInt32(100), UInt32(10_000), UInt32(3), false, UInt32(2000), "")
        profile = DriverProfileConfig(
            "raw",
            UInt32(8),
            UInt16(256),
            UInt8(8),
            [DriverPoolConfig(UInt16(1), UInt32(4096))],
        )
        streams = Dict("cam1" => DriverStreamConfig("cam1", UInt32(42), "raw"))
        cfg = DriverConfig(endpoints, shm, policies, Dict("raw" => profile), streams)

        driver_state = init_driver(cfg; client = client)

        producer_client = init_driver_client(
            client,
            "aeron:ipc",
            Int32(13000),
            UInt32(10),
            DriverRole.PRODUCER,
        )
        consumer_client = init_driver_client(
            client,
            "aeron:ipc",
            Int32(13000),
            UInt32(20),
            DriverRole.CONSUMER,
        )

        prod_attach = wait_for_attach!(driver_state, producer_client, UInt32(42))
        cons_attach = wait_for_attach!(driver_state, consumer_client, UInt32(42))

        producer_cfg = ProducerConfig(
            Aeron.MediaDriver.aeron_dir(media_driver),
            "aeron:ipc",
            Int32(14001),
            Int32(14002),
            Int32(14003),
            Int32(14004),
            UInt32(42),
            UInt32(7),
            UInt32(1),
            UInt32(8),
            base_dir,
            "tensorpool",
            "producer-test",
            "",
            PayloadPoolConfig[],
            UInt8(MAX_DIMS),
            UInt64(1_000_000_000),
            UInt64(1_000_000_000),
            UInt64(250_000),
            UInt64(65536),
        )
        consumer_cfg = ConsumerSettings(
            Aeron.MediaDriver.aeron_dir(media_driver),
            "aeron:ipc",
            Int32(14001),
            Int32(14002),
            Int32(14003),
            UInt32(42),
            UInt32(99),
            UInt32(1),
            UInt8(MAX_DIMS),
            Mode.STREAM,
            UInt32(0),
            true,
            true,
            false,
            UInt16(0),
            "",
            base_dir,
            [base_dir],
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

        producer_state = init_producer_from_attach(
            producer_cfg,
            prod_attach;
            driver_client = producer_client,
            client = client,
        )
        consumer_state = init_consumer_from_attach(
            consumer_cfg,
            cons_attach;
            driver_client = consumer_client,
            client = client,
        )

        count = Ref(0)
        hooks = ConsumerHooks(TestFrameHook(count))
        desc_asm = make_descriptor_assembler(consumer_state; hooks = hooks)
        ctrl_asm = make_control_assembler(consumer_state)

        payload = Vector{UInt8}(undef, 64)
        shape = Int32[64]
        strides = Int32[1]
        target = 5
        now_ns = UInt64(0)

        ok = wait_for() do
            now_ns = UInt64(time_ns())
            driver_do_work!(driver_state)
            driver_client_do_work!(producer_client, now_ns)
            driver_client_do_work!(consumer_client, now_ns)
            offer_frame!(
                producer_state,
                payload,
                shape,
                strides,
                Dtype.UINT8,
                UInt32(0),
            )
            consumer_do_work!(consumer_state, desc_asm, ctrl_asm)
            count[] >= target
        end
        @test ok

        close_producer_state!(producer_state)
        close_consumer_state!(consumer_state)
        close_driver_state!(driver_state)
    end
end
