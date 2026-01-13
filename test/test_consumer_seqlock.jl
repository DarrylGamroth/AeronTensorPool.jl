@testset "Consumer seqlock drops" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            nslots = UInt32(8)
            stride = UInt32(4096)
            layout_version = UInt32(1)
            stream_id = UInt32(101)
            epoch = UInt64(1)

            _, header_path, pool_path = prepare_canonical_shm_layout(
                dir;
                namespace = "tensorpool",
                stream_id = stream_id,
                epoch = Int(epoch),
                pool_id = 1,
            )
            header_uri = "shm:file?path=$(header_path)"
            pool_uri = "shm:file?path=$(pool_path)"

            header_mmap = mmap_shm(header_uri, SUPERBLOCK_SIZE + Int(nslots) * HEADER_SLOT_BYTES; write = true)
            pool_mmap = mmap_shm(pool_uri, SUPERBLOCK_SIZE + Int(nslots) * Int(stride); write = true)

            sb_enc = ShmRegionSuperblock.Encoder(Vector{UInt8})
            wrap_superblock!(sb_enc, header_mmap, 0)
            write_superblock!(
                sb_enc,
                SuperblockFields(
                    MAGIC_TPOLSHM1,
                    layout_version,
                    epoch,
                    stream_id,
                    RegionType.HEADER_RING,
                    UInt16(0),
                    nslots,
                    UInt32(HEADER_SLOT_BYTES),
                    UInt32(0),
                    UInt64(1234),
                    UInt64(0),
                    UInt64(0),
                ),
            )
            wrap_superblock!(sb_enc, pool_mmap, 0)
            write_superblock!(
                sb_enc,
                SuperblockFields(
                    MAGIC_TPOLSHM1,
                    layout_version,
                    epoch,
                    stream_id,
                    RegionType.PAYLOAD_POOL,
                    UInt16(1),
                    nslots,
                    stride,
                    stride,
                    UInt64(1234),
                    UInt64(0),
                    UInt64(0),
                ),
            )

            consumer_cfg = ConsumerConfig(
                Aeron.MediaDriver.aeron_dir(driver),
                "aeron:ipc",
                Int32(12062),
                Int32(12061),
                Int32(12063),
                stream_id,
                UInt32(71),
                layout_version,
                UInt8(MAX_DIMS),
                Mode.STREAM,
                UInt32(256),
                true,
                true,
                false,
                UInt16(0),
                "",
                dir,
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

            announce_buf = Vector{UInt8}(undef, 1024)
            announce_enc = AeronTensorPool.ShmPoolAnnounce.Encoder(Vector{UInt8})
            AeronTensorPool.ShmPoolAnnounce.wrap_and_apply_header!(announce_enc, announce_buf, 0)
            AeronTensorPool.ShmPoolAnnounce.streamId!(announce_enc, stream_id)
            AeronTensorPool.ShmPoolAnnounce.producerId!(announce_enc, UInt32(7))
            AeronTensorPool.ShmPoolAnnounce.epoch!(announce_enc, epoch)
            AeronTensorPool.ShmPoolAnnounce.announceTimestampNs!(announce_enc, UInt64(time_ns()))
            AeronTensorPool.ShmPoolAnnounce.announceClockDomain!(announce_enc, AeronTensorPool.ClockDomain.MONOTONIC)
            AeronTensorPool.ShmPoolAnnounce.layoutVersion!(announce_enc, layout_version)
            AeronTensorPool.ShmPoolAnnounce.headerNslots!(announce_enc, nslots)
            AeronTensorPool.ShmPoolAnnounce.headerSlotBytes!(announce_enc, UInt16(HEADER_SLOT_BYTES))
            pools = AeronTensorPool.ShmPoolAnnounce.payloadPools!(announce_enc, 1)
            pool = AeronTensorPool.ShmPoolAnnounce.PayloadPools.next!(pools)
            AeronTensorPool.ShmPoolAnnounce.PayloadPools.poolId!(pool, UInt16(1))
            AeronTensorPool.ShmPoolAnnounce.PayloadPools.regionUri!(pool, pool_uri)
            AeronTensorPool.ShmPoolAnnounce.PayloadPools.poolNslots!(pool, nslots)
            AeronTensorPool.ShmPoolAnnounce.PayloadPools.strideBytes!(pool, stride)
            AeronTensorPool.ShmPoolAnnounce.headerRegionUri!(announce_enc, header_uri)
            header = MessageHeader.Decoder(announce_buf, 0)
            announce_dec = AeronTensorPool.ShmPoolAnnounce.Decoder(Vector{UInt8})
            AeronTensorPool.ShmPoolAnnounce.wrap!(announce_dec, announce_buf, 0; header = header)
            @test Consumer.map_from_announce!(state, announce_dec)

            desc_buf = Vector{UInt8}(undef, 256)
            desc_enc = FrameDescriptor.Encoder(Vector{UInt8})
            FrameDescriptor.wrap_and_apply_header!(desc_enc, desc_buf, 0)
            FrameDescriptor.streamId!(desc_enc, stream_id)
            FrameDescriptor.epoch!(desc_enc, epoch)
            FrameDescriptor.seq!(desc_enc, UInt64(1))
            FrameDescriptor.timestampNs!(desc_enc, UInt64(0))
            FrameDescriptor.metaVersion!(desc_enc, UInt32(1))
            FrameDescriptor.traceId!(desc_enc, UInt64(0))
            desc_header = MessageHeader.Decoder(desc_buf, 0)
            desc_dec = FrameDescriptor.Decoder(Vector{UInt8})
            FrameDescriptor.wrap!(desc_dec, desc_buf, 0; header = desc_header)

            header_offset = header_slot_offset(UInt32(0))
            slot_enc = SlotHeaderMsg.Encoder(Vector{UInt8})
            tensor_enc = TensorHeaderMsg.Encoder(Vector{UInt8})
            wrap_slot_header!(slot_enc, header_mmap, header_offset)
            write_slot_header!(
                slot_enc,
                tensor_enc,
                UInt64(0),
                UInt32(0),
                UInt32(16),
                UInt32(0),
                UInt32(0),
                UInt16(1),
                Dtype.UINT8,
                MajorOrder.ROW,
                UInt8(1),
                AeronTensorPool.ProgressUnit.NONE,
                UInt32(0),
                vcat(Int32(16), zeros(Int32, MAX_DIMS - 1)),
                vcat(Int32(0), zeros(Int32, MAX_DIMS - 1)),
            )

            commit_ptr = header_commit_ptr_from_offset(header_mmap, header_offset)

            seqlock_begin_write!(commit_ptr, UInt64(1))
            drops_before = state.metrics.drops_late
            @test Consumer.try_read_frame!(state, desc_dec) == false
            @test state.metrics.drops_late == drops_before + 1

            seqlock_commit_write!(commit_ptr, UInt64(1))
            state.mappings.last_commit_words[1] = UInt64(4) << 1
            drops_before = state.metrics.drops_late
            @test Consumer.try_read_frame!(state, desc_dec) == false
            @test state.metrics.drops_late == drops_before + 1
            state.mappings.last_commit_words[1] = UInt64(0)

            write_slot_header!(
                slot_enc,
                tensor_enc,
                UInt64(2),
                UInt32(0),
                UInt32(1),
                UInt32(16),
                UInt32(0),
                UInt16(1),
                Dtype.UINT8,
                MajorOrder.ROW,
                UInt8(1),
                AeronTensorPool.ProgressUnit.NONE,
                UInt32(0),
                vcat(Int32(16), zeros(Int32, MAX_DIMS - 1)),
                vcat(Int32(0), zeros(Int32, MAX_DIMS - 1)),
            )
            seqlock_commit_write!(commit_ptr, UInt64(1))
            @test Consumer.try_read_frame!(state, desc_dec) == false

            write_slot_header!(
                slot_enc,
                tensor_enc,
                UInt64(1),
                UInt32(0),
                UInt32(1),
                UInt32(16),
                UInt32(4),
                UInt16(1),
                Dtype.UINT8,
                MajorOrder.ROW,
                UInt8(1),
                AeronTensorPool.ProgressUnit.NONE,
                UInt32(0),
                vcat(Int32(16), zeros(Int32, MAX_DIMS - 1)),
                vcat(Int32(0), zeros(Int32, MAX_DIMS - 1)),
            )
            seqlock_commit_write!(commit_ptr, UInt64(1))
            @test Consumer.try_read_frame!(state, desc_dec) == false
            finally
                close_consumer_state!(state)
            end
        end
    end
end
