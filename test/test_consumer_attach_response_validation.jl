using Test

@testset "Consumer attach response validation" begin
    with_driver_and_client() do driver, client
        consumer_cfg = ConsumerSettings(
            Aeron.MediaDriver.aeron_dir(driver),
            "aeron:ipc",
            Int32(1000),
            Int32(1001),
            Int32(1002),
            UInt32(7),
            UInt32(17),
            UInt32(1),
            UInt8(MAX_DIMS),
            Mode.STREAM,
            UInt32(0),
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
        state = init_consumer(consumer_cfg; client = client)

        attach = AttachResponse()
        attach.code = DriverResponseCode.OK
        attach.lease_id = ShmAttachResponse.leaseId_null_value(ShmAttachResponse.Decoder)
        @test !map_from_attach_response!(state, attach)

        attach.lease_id = UInt64(1)
        attach.stream_id = UInt32(7)
        attach.epoch = UInt64(1)
        attach.layout_version = UInt32(1)
        attach.header_nslots = UInt32(8)
        attach.header_slot_bytes = UInt16(HEADER_SLOT_BYTES)
        attach.max_dims = UInt8(MAX_DIMS)
        attach.pool_count = 1
        empty!(attach.header_region_uri)
        @test !map_from_attach_response!(state, attach)
    end
end
