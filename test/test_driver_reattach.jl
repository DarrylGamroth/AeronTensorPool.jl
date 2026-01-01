using Test

function wait_for_attach_reattach!(
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
        client.poller.last_attach !== nothing && client.poller.last_attach.correlation_id == cid
    end
    @test ok
    attach = client.poller.last_attach
    @test attach !== nothing
    @test attach.code == DriverResponseCode.OK
    AeronTensorPool.apply_attach!(client, attach)
    return attach
end

@testset "Driver reattach on revoke" begin
    with_embedded_driver() do media_driver
        base_dir = mktempdir()

        endpoints = DriverEndpoints(
            "driver-test",
            Aeron.MediaDriver.aeron_dir(media_driver),
            "aeron:ipc",
            13100,
            "aeron:ipc",
            13101,
            "aeron:ipc",
            13102,
        )
        shm = DriverShmConfig(base_dir, false, UInt32(4096), "660", [base_dir])
        policies = DriverPolicies(false, "raw", UInt32(100), UInt32(10_000), UInt32(3))
        profile = DriverProfileConfig(
            "raw",
            UInt32(8),
            UInt16(256),
            UInt8(8),
            [DriverPoolConfig(UInt16(1), UInt32(4096))],
        )
        streams = Dict("cam1" => DriverStreamConfig("cam1", UInt32(43), "raw"))
        cfg = DriverConfig(
            endpoints,
            shm,
            policies,
            Dict("raw" => profile),
            streams,
        )

        driver_state = init_driver(cfg)

        with_client(; driver = media_driver) do control_client
            producer_client = init_driver_client(
                control_client,
                "aeron:ipc",
                Int32(13100),
                UInt32(30),
                DriverRole.PRODUCER,
            )
            consumer_client = init_driver_client(
                control_client,
                "aeron:ipc",
                Int32(13100),
                UInt32(31),
                DriverRole.CONSUMER,
            )

            prod_attach = wait_for_attach_reattach!(driver_state, producer_client, UInt32(43))
            cons_attach = wait_for_attach_reattach!(driver_state, consumer_client, UInt32(43))

            producer_cfg = ProducerConfig(
                Aeron.MediaDriver.aeron_dir(media_driver),
                "aeron:ipc",
                Int32(14101),
                Int32(14102),
                Int32(14103),
                Int32(14104),
                UInt32(43),
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
            consumer_cfg = ConsumerConfig(
                Aeron.MediaDriver.aeron_dir(media_driver),
                "aeron:ipc",
                Int32(14101),
                Int32(14102),
                Int32(14103),
                UInt32(43),
                UInt32(99),
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
                UInt64(1_000_000_000),
                UInt64(1_000_000_000),
            )

            producer_state = init_producer_from_attach(
                producer_cfg,
                prod_attach;
                driver_client = producer_client,
            )
            consumer_state = init_consumer_from_attach(
                consumer_cfg,
                cons_attach;
                driver_client = consumer_client,
            )

            prod_control_asm = make_control_assembler(producer_state)
            cons_desc_asm = make_descriptor_assembler(consumer_state)
            cons_ctrl_asm = make_control_assembler(consumer_state)

            old_epoch = producer_state.epoch
            AeronTensorPool.revoke_lease!(
                driver_state,
                producer_client.lease_id,
                DriverLeaseRevokeReason.EXPIRED,
                UInt64(time_ns()),
            )

            ok = wait_for() do
                driver_do_work!(driver_state)
                producer_do_work!(producer_state, prod_control_asm)
                producer_state.driver_active && producer_state.epoch != old_epoch
            end
            @test ok
            @test producer_client.lease_id != 0

            AeronTensorPool.revoke_lease!(
                driver_state,
                consumer_client.lease_id,
                DriverLeaseRevokeReason.EXPIRED,
                UInt64(time_ns()),
            )
            ok = wait_for() do
                driver_do_work!(driver_state)
                consumer_do_work!(consumer_state, cons_desc_asm, cons_ctrl_asm)
                consumer_state.driver_active && consumer_client.lease_id != 0
            end
            @test ok

            close_producer_state!(producer_state)
            close_consumer_state!(consumer_state)
        end

        close_driver_state!(driver_state)
    end
end
