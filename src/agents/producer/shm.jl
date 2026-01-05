"""
Initialize SHM regions, write superblocks, and return mappings plus encoder.
"""
function init_producer_shm!(config::ProducerConfig, clock::Clocks.AbstractClock)
    header_size = SUPERBLOCK_SIZE + Int(config.nslots) * HEADER_SLOT_BYTES
    header_mmap = mmap_shm(config.header_uri, header_size; write = true)
    if config.mlock_shm
        mlock_buffer!(header_mmap, "producer header")
    end

    sb_encoder = ShmRegionSuperblock.Encoder(Vector{UInt8})
    wrap_superblock!(sb_encoder, header_mmap, 0)
    now_ns = UInt64(Clocks.time_nanos(clock))
    write_superblock!(
        sb_encoder,
        SuperblockFields(
            MAGIC_TPOLSHM1,
            config.layout_version,
            UInt64(1),
            config.stream_id,
            RegionType.HEADER_RING,
            UInt16(0),
            config.nslots,
            UInt32(HEADER_SLOT_BYTES),
            UInt32(0),
            UInt64(getpid()),
            now_ns,
            now_ns,
        ),
    )

    payload_mmaps = Dict{UInt16, Vector{UInt8}}()
    for pool in config.payload_pools
        pool_size = SUPERBLOCK_SIZE + Int(pool.nslots) * Int(pool.stride_bytes)
        pmmap = mmap_shm(pool.uri, pool_size; write = true)
        if config.mlock_shm
            mlock_buffer!(pmmap, "producer pool")
        end
        wrap_superblock!(sb_encoder, pmmap, 0)
        write_superblock!(
            sb_encoder,
            SuperblockFields(
                MAGIC_TPOLSHM1,
                config.layout_version,
                UInt64(1),
                config.stream_id,
                RegionType.PAYLOAD_POOL,
                pool.pool_id,
                pool.nslots,
                pool.stride_bytes,
                pool.stride_bytes,
                UInt64(getpid()),
                now_ns,
                now_ns,
            ),
        )
        payload_mmaps[pool.pool_id] = pmmap
    end

    return ProducerMappings(header_mmap, payload_mmaps), sb_encoder
end

"""
Map driver-provisioned SHM regions for a producer config.
"""
function map_producer_from_attach(config::ProducerConfig, attach::AttachResponse)
    attach.code == DriverResponseCode.OK || return nothing
    attach.header_slot_bytes == UInt16(HEADER_SLOT_BYTES) || return nothing

    header_size = SUPERBLOCK_SIZE + Int(config.nslots) * HEADER_SLOT_BYTES
    header_mmap = mmap_shm_existing(config.header_uri, header_size; write = true)
    if config.mlock_shm
        mlock_buffer!(header_mmap, "producer header")
    end

    sb_dec = ShmRegionSuperblock.Decoder(Vector{UInt8})
    wrap_superblock!(sb_dec, header_mmap, 0)
    header_fields = try
        read_superblock(sb_dec)
    catch
        return nothing
    end
    header_ok = validate_superblock_fields(
        header_fields;
        expected_layout_version = config.layout_version,
        expected_epoch = attach.epoch,
        expected_stream_id = config.stream_id,
        expected_nslots = config.nslots,
        expected_slot_bytes = UInt32(HEADER_SLOT_BYTES),
        expected_region_type = RegionType.HEADER_RING,
        expected_pool_id = UInt16(0),
    )
    header_ok || return nothing

    payload_mmaps = Dict{UInt16, Vector{UInt8}}()
    for pool in config.payload_pools
        pool_size = SUPERBLOCK_SIZE + Int(pool.nslots) * Int(pool.stride_bytes)
        pmmap = mmap_shm_existing(pool.uri, pool_size; write = true)
        if config.mlock_shm
            mlock_buffer!(pmmap, "producer pool")
        end
        wrap_superblock!(sb_dec, pmmap, 0)
        pool_fields = try
            read_superblock(sb_dec)
        catch
            return nothing
        end
        pool_ok = validate_superblock_fields(
            pool_fields;
            expected_layout_version = config.layout_version,
            expected_epoch = attach.epoch,
            expected_stream_id = config.stream_id,
            expected_nslots = pool.nslots,
            expected_slot_bytes = pool.stride_bytes,
            expected_region_type = RegionType.PAYLOAD_POOL,
            expected_pool_id = pool.pool_id,
        )
        pool_ok || return nothing
        payload_mmaps[pool.pool_id] = pmmap
    end

    return ProducerMappings(header_mmap, payload_mmaps)
end
