using Test

function wait_for_attach_discovery!(
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

@testset "Discovery end-to-end with driver attach" begin
    with_driver_and_client() do media_driver, client
        base_dir = mktempdir()

            uri = "aeron:ipc"
            stream_id = UInt32(77)
            control_stream = Int32(15100)
            announce_stream = Int32(15101)
            qos_stream = Int32(15102)
            descriptor_stream = Int32(15103)
            metadata_stream = Int32(15104)

            discovery_stream = Int32(16100)
            response_stream = UInt32(16101)

            endpoints = DriverEndpoints(
                "driver-test",
                Aeron.MediaDriver.aeron_dir(media_driver),
                uri,
                control_stream,
                uri,
                announce_stream,
                uri,
                qos_stream,
            )
            shm = DriverShmConfig(base_dir, false, UInt32(4096), "660", [base_dir])
            policies =
                DriverPolicies(false, "raw", UInt32(50), UInt32(1000), UInt32(5), false, false, UInt32(2000), "")
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

            discovery_cfg = DiscoveryConfig(
                uri,
                discovery_stream,
                uri,
                announce_stream,
                "",
                0,
                endpoints.instance_id,
                uri,
                UInt32(control_stream),
                AeronTensorPool.DISCOVERY_MAX_RESULTS_DEFAULT,
                UInt64(5_000_000_000),
                AeronTensorPool.DISCOVERY_RESPONSE_BUF_BYTES,
                AeronTensorPool.DISCOVERY_MAX_TAGS_PER_ENTRY_DEFAULT,
                AeronTensorPool.DISCOVERY_MAX_POOLS_PER_ENTRY_DEFAULT,
            )
            validate_discovery_endpoints(
                endpoints.control_channel,
                endpoints.control_stream_id,
                discovery_cfg.channel,
                discovery_cfg.stream_id,
                discovery_cfg.channel,
                response_stream,
            )
            discovery_state = AeronTensorPool.Agents.Discovery.init_discovery_provider(discovery_cfg; client = client)
            req_asm = AeronTensorPool.Agents.Discovery.make_request_assembler(discovery_state)
            ann_asm = AeronTensorPool.Agents.Discovery.make_announce_assembler(discovery_state)

            discovery_client = init_discovery_client(
                client,
                uri,
                discovery_stream,
                uri,
                response_stream,
                UInt32(42),
            )
            entries = Vector{DiscoveryEntry}()

            producer_client = init_driver_client(
                client,
                uri,
                control_stream,
                UInt32(10),
                DriverRole.PRODUCER,
                keepalive_interval_ns = UInt64(200_000_000),
            )
            prod_attach = wait_for_attach_discovery!(driver_state, producer_client, stream_id)

            producer_cfg = ProducerConfig(
                Aeron.MediaDriver.aeron_dir(media_driver),
                uri,
                descriptor_stream,
                announce_stream,
                qos_stream,
                metadata_stream,
                stream_id,
                UInt32(1),
                UInt32(1),
                UInt32(8),
                base_dir,
                "tensorpool",
                "discovery-producer",
                "",
                PayloadPoolConfig[],
                UInt8(MAX_DIMS),
                UInt64(10_000_000),
                UInt64(10_000_000),
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

            ok = wait_for() do
                driver_do_work!(driver_state)
                Producer.producer_do_work!(producer_state, prod_ctrl; qos_assembler = prod_qos)
                AeronTensorPool.Agents.Discovery.discovery_do_work!(discovery_state, req_asm, ann_asm)
                !isempty(discovery_state.entries)
            end
            @test ok

            request_id = discover_streams!(discovery_client, entries)
            @test request_id != 0
            slot = nothing
            ok = wait_for() do
                driver_do_work!(driver_state)
                Producer.producer_do_work!(producer_state, prod_ctrl; qos_assembler = prod_qos)
                AeronTensorPool.Agents.Discovery.discovery_do_work!(discovery_state, req_asm, ann_asm)
                slot = poll_discovery_response!(discovery_client, request_id)
                slot !== nothing
            end
            @test ok
            @test slot.status == DiscoveryStatus.OK
            @test slot.count > 0
            entry = slot.out_entries[1]
            @test entry.stream_id == stream_id
            @test entry.driver_control_stream_id == UInt32(control_stream)

            consumer_client = init_driver_client(
                client,
                uri,
                control_stream,
                UInt32(20),
                DriverRole.CONSUMER,
                keepalive_interval_ns = UInt64(200_000_000),
            )
            cons_attach = wait_for_attach_discovery!(driver_state, consumer_client, entry.stream_id)
            @test cons_attach.code == DriverResponseCode.OK

        close_producer_state!(producer_state)
        close_driver_state!(driver_state)
    end
end
