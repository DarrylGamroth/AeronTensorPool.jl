using Test

function wait_for_attach_full!(
    driver_state::DriverState,
    client::DriverClientState,
    stream_id::UInt32,
)
    cid = send_attach_request!(
        client;
        stream_id = stream_id,
        publish_mode = DriverPublishMode.REQUIRE_EXISTING,
    )
    @test cid != 0
    ok = wait_for() do
        driver_do_work!(driver_state)
        driver_client_do_work!(client, UInt64(time_ns()))
        attach = client.poller.last_attach
        attach !== nothing && attach.correlation_id == cid
    end
    @test ok
    attach = client.poller.last_attach
    @test attach !== nothing
    @test attach.code == DriverResponseCode.OK
    AeronTensorPool.apply_attach!(client, attach)
    return attach
end

@testset "Full stack driver mode" begin
    with_driver_and_client() do media_driver, client
        base_dir = mktempdir()

            driver_control_stream = Int32(15010)
            pool_control_stream = Int32(15011)
            qos_stream = Int32(15012)
            descriptor_stream = Int32(15013)
            metadata_stream = Int32(15014)
            uri = "aeron:ipc"
            stream_id = UInt32(77)

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
            shm = DriverShmConfig(base_dir, false, UInt32(4096), "660", [base_dir])
            policies = DriverPolicies(false, "raw", UInt32(50), UInt32(1000), UInt32(5), UInt32(2000), "")
            profile = DriverProfileConfig(
                "raw",
                UInt32(8),
                UInt16(256),
                UInt8(8),
                [DriverPoolConfig(UInt16(1), UInt32(4096))],
            )
            streams = Dict("cam1" => DriverStreamConfig("cam1", stream_id, "raw"))
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
                uri,
                driver_control_stream,
                UInt32(10),
                DriverRole.PRODUCER,
                keepalive_interval_ns = UInt64(200_000_000),
            )
            consumer_client = init_driver_client(
                client,
                uri,
                driver_control_stream,
                UInt32(20),
                DriverRole.CONSUMER,
                keepalive_interval_ns = UInt64(200_000_000),
            )

            prod_attach = wait_for_attach_full!(driver_state, producer_client, stream_id)
            cons_attach = wait_for_attach_full!(driver_state, consumer_client, stream_id)

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
                "fullstack-producer",
                "",
                PayloadPoolConfig[],
                UInt8(MAX_DIMS),
                UInt64(10_000_000),
                UInt64(10_000_000),
                UInt64(250_000),
                UInt64(65536),
            )
            consumer_cfg = ConsumerSettings(
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
                UInt16(1),
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
            )
            supervisor_cfg = SupervisorConfig(
                Aeron.MediaDriver.aeron_dir(media_driver),
                uri,
                pool_control_stream,
                qos_stream,
                stream_id,
                UInt64(30_000_000_000),
                UInt64(10_000_000_000),
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
            supervisor_state = init_supervisor(supervisor_cfg; client = client)

            prod_ctrl = make_control_assembler(producer_state)
            prod_qos = make_qos_assembler(producer_state)
            cons_ctrl = make_control_assembler(consumer_state)
            sup_ctrl = make_control_assembler(supervisor_state)
            sup_qos = make_qos_assembler(supervisor_state)

            got_frame = Ref(false)
            handler = Aeron.FragmentHandler(consumer_state) do st, buffer, _
                header = MessageHeader.Decoder(buffer, 0)
                if MessageHeader.templateId(header) == AeronTensorPool.TEMPLATE_FRAME_DESCRIPTOR
                    FrameDescriptor.wrap!(st.runtime.desc_decoder, buffer, 0; header = header)
                    result = try_read_frame!(st, st.runtime.desc_decoder)
                    result && (got_frame[] = true)
                end
                nothing
            end
            cons_desc = Aeron.FragmentAssembler(handler)

            payload = UInt8[1, 2, 3, 4]
            shape = Int32[4]
            strides = Int32[0]
            ok = wait_for() do
                driver_do_work!(driver_state)
                producer_do_work!(producer_state, prod_ctrl; qos_assembler = prod_qos)
                consumer_do_work!(consumer_state, cons_desc, cons_ctrl)
                supervisor_do_work!(supervisor_state, sup_ctrl, sup_qos)

                if consumer_state.mappings.header_mmap !== nothing && !got_frame[]
                    publish_frame!(producer_state, payload, shape, strides, Dtype.UINT8, UInt32(0))
                end

                got_frame[] &&
                    !isempty(supervisor_state.tracking.producers) &&
                    !isempty(supervisor_state.tracking.consumers)
            end
            @test ok

        close_producer_state!(producer_state)
        close_consumer_state!(consumer_state)
        close_supervisor_state!(supervisor_state)
        close_driver_state!(driver_state)
    end
end
