@testset "Driver attach remap uses latest response buffers" begin
    with_driver_and_client() do media_driver, client
        base_dir = mktempdir()

        nslots = UInt32(4)
        stride = UInt32(4096)
        stream_id = UInt32(55)

        function write_layout(header_uri::String, pool_uri::String, epoch::UInt64)
            header_size = SUPERBLOCK_SIZE + HEADER_SLOT_BYTES * Int(nslots)
            header_mmap = mmap_shm(header_uri, header_size; write = true)
            sb_enc = ShmRegionSuperblock.Encoder(Vector{UInt8})
            wrap_superblock!(sb_enc, header_mmap, 0)
            write_superblock!(
                sb_enc,
                SuperblockFields(
                    MAGIC_TPOLSHM1,
                    UInt32(1),
                    epoch,
                    stream_id,
                    RegionType.HEADER_RING,
                    UInt16(0),
                    nslots,
                    UInt32(HEADER_SLOT_BYTES),
                    UInt32(0),
                    UInt64(111),
                    UInt64(0),
                    UInt64(0),
                ),
            )

            pool_size = SUPERBLOCK_SIZE + Int(nslots) * Int(stride)
            pool_mmap = mmap_shm(pool_uri, pool_size; write = true)
            wrap_superblock!(sb_enc, pool_mmap, 0)
            write_superblock!(
                sb_enc,
                SuperblockFields(
                    MAGIC_TPOLSHM1,
                    UInt32(1),
                    epoch,
                    stream_id,
                    RegionType.PAYLOAD_POOL,
                    UInt16(1),
                    nslots,
                    stride,
                    stride,
                    UInt64(111),
                    UInt64(0),
                    UInt64(0),
                ),
            )
            return nothing
        end

        _, header_path1, pool_path1 = prepare_canonical_shm_layout(
            base_dir;
            namespace = "tensorpool",
            stream_id = stream_id,
            epoch = 1,
            pool_id = 1,
        )
        header_uri1 = "shm:file?path=$(header_path1)"
        pool_uri1 = "shm:file?path=$(pool_path1)"
        write_layout(header_uri1, pool_uri1, UInt64(1))

        _, header_path2, pool_path2 = prepare_canonical_shm_layout(
            base_dir;
            namespace = "tensorpool",
            stream_id = stream_id,
            epoch = 2,
            pool_id = 1,
        )
        header_uri2 = "shm:file?path=$(header_path2)"
        pool_uri2 = "shm:file?path=$(pool_path2)"
        write_layout(header_uri2, pool_uri2, UInt64(2))

        consumer_cfg = ConsumerConfig(
            Aeron.MediaDriver.aeron_dir(media_driver),
            "aeron:ipc",
            Int32(15101),
            Int32(15102),
            Int32(15103),
            stream_id,
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
            false,
        )
        consumer_state = Consumer.init_consumer(consumer_cfg; client = client)

        buf = Vector{UInt8}(undef, 4096)
        enc = ShmAttachResponse.Encoder(Vector{UInt8})
        dec = ShmAttachResponse.Decoder(Vector{UInt8})
        resp = AttachResponse()

        function encode_attach!(header_uri::String, pool_uri::String, epoch::UInt64)
            ShmAttachResponse.wrap_and_apply_header!(enc, buf, 0)
            ShmAttachResponse.correlationId!(enc, Int64(1))
            ShmAttachResponse.code!(enc, DriverResponseCode.OK)
            ShmAttachResponse.leaseId!(enc, UInt64(10))
            ShmAttachResponse.leaseExpiryTimestampNs!(enc, UInt64(123))
            ShmAttachResponse.streamId!(enc, stream_id)
            ShmAttachResponse.epoch!(enc, epoch)
            ShmAttachResponse.layoutVersion!(enc, UInt32(1))
            ShmAttachResponse.headerNslots!(enc, nslots)
            ShmAttachResponse.headerSlotBytes!(enc, UInt16(HEADER_SLOT_BYTES))
            ShmAttachResponse.maxDims!(enc, UInt8(MAX_DIMS))
            pools = ShmAttachResponse.payloadPools!(enc, 1)
            entry = ShmAttachResponse.PayloadPools.next!(pools)
            ShmAttachResponse.PayloadPools.poolId!(entry, UInt16(1))
            ShmAttachResponse.PayloadPools.poolNslots!(entry, nslots)
            ShmAttachResponse.PayloadPools.strideBytes!(entry, stride)
            ShmAttachResponse.PayloadPools.regionUri!(entry, pool_uri)
            ShmAttachResponse.headerRegionUri!(enc, header_uri)
            ShmAttachResponse.errorMessage!(enc, "")
            return nothing
        end

        encode_attach!(header_uri1, pool_uri1, UInt64(1))
        header = DriverMessageHeader.Decoder(buf, 0)
        ShmAttachResponse.wrap!(dec, buf, 0; header = header)
        AeronTensorPool.snapshot_attach_response!(resp, dec)
        @test Consumer.map_from_attach_response!(consumer_state, resp)
        wrap_superblock!(consumer_state.runtime.superblock_decoder, consumer_state.mappings.header_mmap, 0)
        fields = read_superblock(consumer_state.runtime.superblock_decoder)
        @test fields.epoch == UInt64(1)

        encode_attach!(header_uri2, pool_uri2, UInt64(2))
        header = DriverMessageHeader.Decoder(buf, 0)
        ShmAttachResponse.wrap!(dec, buf, 0; header = header)
        AeronTensorPool.snapshot_attach_response!(resp, dec)
        @test Consumer.remap_consumer_from_attach!(consumer_state, resp)
        wrap_superblock!(consumer_state.runtime.superblock_decoder, consumer_state.mappings.header_mmap, 0)
        fields = read_superblock(consumer_state.runtime.superblock_decoder)
        @test fields.epoch == UInt64(2)

        close_consumer_state!(consumer_state)
    end
end
