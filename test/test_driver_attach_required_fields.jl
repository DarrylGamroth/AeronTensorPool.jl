using Test

function valid_attach_response()
    attach = AttachResponse()
    attach.code = DriverResponseCode.OK
    attach.lease_id = UInt64(1)
    attach.stream_id = UInt32(10000)
    attach.epoch = UInt64(2)
    attach.layout_version = UInt32(1)
    attach.header_nslots = UInt32(8)
    attach.header_slot_bytes = UInt16(HEADER_SLOT_BYTES)
    attach.max_dims = UInt8(MAX_DIMS)
    copyto!(attach.header_region_uri, "shm:file?path=/dev/shm/tp_header")
    attach.pools = [DriverPool()]
    attach.pool_count = 1
    attach.pools[1].pool_id = UInt16(1)
    attach.pools[1].pool_nslots = UInt32(8)
    attach.pools[1].stride_bytes = UInt32(4096)
    copyto!(attach.pools[1].region_uri, "shm:file?path=/dev/shm/tp_pool")
    return attach
end

@testset "Attach response required fields (consumer mapping)" begin
    with_driver_and_client() do driver, client
        consumer_cfg = ConsumerConfig(
            Aeron.MediaDriver.aeron_dir(driver),
            "aeron:ipc",
            Int32(15030),
            Int32(15031),
            Int32(15032),
            UInt32(10000),
            UInt32(42),
            UInt32(1),
            UInt8(MAX_DIMS),
            Mode.STREAM,
            UInt32(256),
            true,
            true,
            false,
            UInt16(0),
            "",
            "",
            String[],
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
            false,
        )
        state = Consumer.init_consumer(consumer_cfg; client = client)
        try
            base = valid_attach_response()
            base.lease_id = ShmAttachResponse.leaseId_null_value(ShmAttachResponse.Decoder)
            @test !Consumer.map_from_attach_response!(state, base)

            base = valid_attach_response()
            base.stream_id = ShmAttachResponse.streamId_null_value(ShmAttachResponse.Decoder)
            @test !Consumer.map_from_attach_response!(state, base)

            base = valid_attach_response()
            base.epoch = ShmAttachResponse.epoch_null_value(ShmAttachResponse.Decoder)
            @test !Consumer.map_from_attach_response!(state, base)

            base = valid_attach_response()
            base.layout_version = ShmAttachResponse.layoutVersion_null_value(ShmAttachResponse.Decoder)
            @test !Consumer.map_from_attach_response!(state, base)

            base = valid_attach_response()
            base.header_nslots = ShmAttachResponse.headerNslots_null_value(ShmAttachResponse.Decoder)
            @test !Consumer.map_from_attach_response!(state, base)

            base = valid_attach_response()
            base.header_slot_bytes = ShmAttachResponse.headerSlotBytes_null_value(ShmAttachResponse.Decoder)
            @test !Consumer.map_from_attach_response!(state, base)

            base = valid_attach_response()
            base.max_dims = ShmAttachResponse.maxDims_null_value(ShmAttachResponse.Decoder)
            @test !Consumer.map_from_attach_response!(state, base)

            base = valid_attach_response()
            empty!(base.header_region_uri)
            @test !Consumer.map_from_attach_response!(state, base)

            base = valid_attach_response()
            base.pool_count = 0
            @test !Consumer.map_from_attach_response!(state, base)
        finally
            close_consumer_state!(state)
        end
    end
end

@testset "Attach response required fields (producer init)" begin
    with_driver_and_client() do driver, client
        cfg = ProducerConfig(
            Aeron.MediaDriver.aeron_dir(driver),
            "aeron:ipc",
            Int32(16010),
            Int32(16011),
            Int32(16012),
            Int32(16013),
            UInt32(10000),
            UInt32(7),
            UInt32(1),
            UInt32(8),
            "/dev/shm",
            "tensorpool",
            "attach-test",
            "shm:file?path=/dev/shm/tp_header",
            [PayloadPoolConfig(UInt16(1), "shm:file?path=/dev/shm/tp_pool", UInt32(4096), UInt32(8))],
            UInt8(MAX_DIMS),
            UInt64(1_000_000_000),
            UInt64(1_000_000_000),
            UInt64(250_000),
            UInt64(65536),
            false,
        )

        base = valid_attach_response()
        base.lease_id = ShmAttachResponse.leaseId_null_value(ShmAttachResponse.Decoder)
        @test_throws ArgumentError Producer.init_producer_from_attach(cfg, base; client = client)

        base = valid_attach_response()
        base.stream_id = ShmAttachResponse.streamId_null_value(ShmAttachResponse.Decoder)
        @test_throws ArgumentError Producer.init_producer_from_attach(cfg, base; client = client)

        base = valid_attach_response()
        base.epoch = ShmAttachResponse.epoch_null_value(ShmAttachResponse.Decoder)
        @test_throws ArgumentError Producer.init_producer_from_attach(cfg, base; client = client)

        base = valid_attach_response()
        base.layout_version = ShmAttachResponse.layoutVersion_null_value(ShmAttachResponse.Decoder)
        @test_throws ArgumentError Producer.init_producer_from_attach(cfg, base; client = client)

        base = valid_attach_response()
        base.header_nslots = ShmAttachResponse.headerNslots_null_value(ShmAttachResponse.Decoder)
        @test_throws ArgumentError Producer.init_producer_from_attach(cfg, base; client = client)

        base = valid_attach_response()
        base.header_slot_bytes = ShmAttachResponse.headerSlotBytes_null_value(ShmAttachResponse.Decoder)
        @test_throws ArgumentError Producer.init_producer_from_attach(cfg, base; client = client)

        base = valid_attach_response()
        base.max_dims = ShmAttachResponse.maxDims_null_value(ShmAttachResponse.Decoder)
        @test_throws ArgumentError Producer.init_producer_from_attach(cfg, base; client = client)

        base = valid_attach_response()
        empty!(base.header_region_uri)
        @test_throws ArgumentError Producer.init_producer_from_attach(cfg, base; client = client)

        base = valid_attach_response()
        base.pool_count = 0
        @test_throws ArgumentError Producer.init_producer_from_attach(cfg, base; client = client)
    end
end
