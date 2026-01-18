using Test

struct FrameCountCallback
    count::Base.RefValue{Int}
end

function (callback::FrameCountCallback)(::ConsumerState, ::ConsumerFrameView)
    callback.count[] += 1
    return nothing
end

function wait_for_attach_app!(
    driver_state::DriverState,
    client::DriverClientState,
    stream_id::UInt32;
    timeout::Float64 = 5.0,
)
    cid = send_attach_request!(client; stream_id = stream_id)
    cid != 0 || return nothing
    ok = wait_for(; timeout = timeout) do
        driver_do_work!(driver_state)
        AeronTensorPool.Control.poll_attach!(client, cid, UInt64(time_ns())) !== nothing
    end
    ok || return nothing
    return client.poller.last_attach
end

@testset "App-style attach and flow" begin
    with_driver_and_client() do media_driver, client
        base_dir = mktempdir()
        driver_control_stream = Int32(15030)
        pool_control_stream = Int32(15031)
        qos_stream = Int32(15032)
        descriptor_stream = Int32(15033)
        metadata_stream = Int32(15034)
        uri = "aeron:ipc"
        stream_id = UInt32(99)

        endpoints = DriverEndpoints(
            "driver-test",
            Aeron.MediaDriver.aeron_dir(media_driver),
            uri,
            driver_control_stream,
            uri,
            pool_control_stream,
            uri,
            qos_stream,
        )
        shm = DriverShmConfig(base_dir, "default", false, UInt32(4096), "660", [base_dir])
        policies = DriverPolicyConfig(false, "raw", UInt32(50), UInt32(1000), UInt32(5), false, false, false, false, UInt32(2000), "")
        profile = DriverProfileConfig(
            "raw",
            UInt32(8),
            UInt16(256),
            UInt8(8),
            [DriverPoolConfig(UInt16(1), UInt32(4096))],
        )
        streams = Dict("cam1" => DriverStreamConfig("cam1", stream_id, "raw"))
        cfg = DriverConfig(endpoints, shm, policies, Dict("raw" => profile), streams)

        driver_state = init_driver(cfg; client = client.aeron_client)
        producer_client = init_driver_client(client.aeron_client,
            uri,
            driver_control_stream,
            UInt32(10),
            DriverRole.PRODUCER,
            keepalive_interval_ns = UInt64(200_000_000),
        )
        consumer_client = init_driver_client(client.aeron_client,
            uri,
            driver_control_stream,
            UInt32(20),
            DriverRole.CONSUMER,
            keepalive_interval_ns = UInt64(200_000_000),
        )

        prod_attach = wait_for_attach_app!(driver_state, producer_client, stream_id)
        cons_attach = wait_for_attach_app!(driver_state, consumer_client, stream_id)
        @test prod_attach !== nothing
        @test cons_attach !== nothing

        producer_cfg = ProducerConfig(
            Aeron.MediaDriver.aeron_dir(media_driver),
            uri,
            descriptor_stream,
            pool_control_stream,
            qos_stream,
            metadata_stream,
            stream_id,
            UInt32(1),
            UInt32(1),
            UInt32(8),
            base_dir,
            "tensorpool",
            "app-flow-producer",
            "",
            PayloadPoolConfig[],
            UInt8(MAX_DIMS),
            UInt64(10_000_000),
            UInt64(10_000_000),
            UInt64(250_000),
            UInt64(65536),
            false,
        )
        consumer_cfg = ConsumerConfig(
            Aeron.MediaDriver.aeron_dir(media_driver),
            uri,
            descriptor_stream,
            pool_control_stream,
            qos_stream,
            stream_id,
            UInt32(2),
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
            UInt64(10_000_000),
            UInt64(10_000_000),
            UInt64(3_000_000_000),
            "",
            UInt32(0),
            "",
            UInt32(0),
            false,
        )

        producer_state = Producer.init_producer_from_attach(
            producer_cfg,
            prod_attach;
            driver_client = producer_client,
            client = client,
        )
        consumer_state = Consumer.init_consumer_from_attach(
            consumer_cfg,
            cons_attach;
            driver_client = consumer_client,
            client = client,
        )
        prod_ctrl = Producer.make_control_assembler(producer_state)
        prod_qos = Producer.make_qos_assembler(producer_state)
        count_ref = Ref(0)
        callbacks = ConsumerCallbacks(FrameCountCallback(count_ref))
        cons_desc = Consumer.make_descriptor_assembler(consumer_state; callbacks = callbacks)
        cons_ctrl = Consumer.make_control_assembler(consumer_state)

        payload = Vector{UInt8}(undef, 256)
        shape = Int32[256]
        strides = Int32[1]

        ok = wait_for(; timeout = 5.0) do
            driver_do_work!(driver_state)
            Producer.producer_do_work!(producer_state, prod_ctrl; qos_assembler = prod_qos)
            Consumer.consumer_do_work!(consumer_state, cons_desc, cons_ctrl)
            if count_ref[] < 5
                fill!(payload, UInt8(count_ref[] % 255))
                Producer.offer_frame!(producer_state, payload, shape, strides, Dtype.UINT8, UInt32(0))
            end
            count_ref[] >= 5
        end
        @test ok

        close_producer_state!(producer_state)
        close_consumer_state!(consumer_state)
        close_driver_state!(driver_state)
    end
end
