@testset "Consumer stride validation" begin
    with_driver_and_client() do driver, client
        consumer_cfg = ConsumerConfig(
            Aeron.MediaDriver.aeron_dir(driver),
            "aeron:ipc",
            Int32(12052),
            Int32(12051),
            Int32(12053),
            UInt32(91),
            UInt32(62),
            UInt32(1),
            UInt8(MAX_DIMS),
            Mode.STREAM,
            UInt32(256),
            false,
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
            dims = (Int32(2), Int32(2), Int32(0), Int32(0), Int32(0), Int32(0), Int32(0), Int32(0))
            ok_strides = (Int32(0), Int32(0), Int32(0), Int32(0), Int32(0), Int32(0), Int32(0), Int32(0))
            bad_strides = (Int32(4), Int32(2), Int32(0), Int32(0), Int32(0), Int32(0), Int32(0), Int32(0))

            header_ok = TensorHeader(
                Dtype.FLOAT32,
                MajorOrder.ROW,
                UInt8(2),
                UInt8(0),
                AeronTensorPool.ProgressUnit.NONE,
                UInt32(0),
                dims,
                ok_strides,
            )
            header_bad = TensorHeader(
                Dtype.FLOAT32,
                MajorOrder.ROW,
                UInt8(2),
                UInt8(0),
                AeronTensorPool.ProgressUnit.NONE,
                UInt32(0),
                dims,
                bad_strides,
            )

            @test Consumer.validate_strides!(state, header_ok, Int64(4))
            @test !Consumer.validate_strides!(state, header_bad, Int64(4))
        finally
            close_consumer_state!(state)
        end
    end
end
