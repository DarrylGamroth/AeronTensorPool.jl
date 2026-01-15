using Test

@testset "Consumer drops payload_slot out of range" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            nslots = UInt32(8)
            stride = UInt32(4096)
            layout_version = UInt32(1)
            stream_id = UInt32(204)
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
            now_ns = UInt64(time_ns())

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
                    now_ns,
                    now_ns,
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
                    now_ns,
                    now_ns,
                ),
            )

            consumer_cfg = ConsumerConfig(
                Aeron.MediaDriver.aeron_dir(driver),
                "aeron:ipc",
                Int32(12150),
                Int32(12151),
                Int32(12152),
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
                announce = build_shm_pool_announce(
                    stream_id = stream_id,
                    epoch = epoch,
                    layout_version = layout_version,
                    nslots = nslots,
                    stride_bytes = stride,
                    header_uri = header_uri,
                    pool_uri = pool_uri,
                )
                @test Consumer.map_from_announce!(state, announce.dec, UInt64(time_ns()))

                seq = UInt64(1)
                (_, desc_dec) = build_frame_descriptor(
                    stream_id = stream_id,
                    epoch = epoch,
                    seq = seq,
                    timestamp_ns = UInt64(0),
                    meta_version = UInt32(1),
                    trace_id = UInt64(0),
                )

                header_index = UInt32(seq & UInt64(nslots - 1))
                header_offset = header_slot_offset(header_index)
                slot_enc = SlotHeaderMsg.Encoder(Vector{UInt8})
                tensor_enc = TensorHeaderMsg.Encoder(Vector{UInt8})
                wrap_slot_header!(slot_enc, header_mmap, header_offset)
                write_slot_header!(
                    slot_enc,
                    tensor_enc,
                    seq,
                    UInt32(0),
                    UInt32(16),
                    UInt32(nslots),
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
                seqlock_commit_write!(commit_ptr, UInt64(1))

                @test !Consumer.try_read_frame!(state, desc_dec)
            finally
                close_consumer_state!(state)
            end
        end
    end
end
