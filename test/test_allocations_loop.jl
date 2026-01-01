@testset "Allocation checks: producer/consumer loop" begin
    with_embedded_driver() do driver
        mktempdir() do dir
            config_path = joinpath(dir, "config.toml")
            open(config_path, "w") do io
                write(
                    io,
                    """
[producer]
aeron_dir = "/dev/shm/aeron-\${USER}"
aeron_uri = "aeron:ipc"
descriptor_stream_id = 1110
control_stream_id = 1111
qos_stream_id = 1112
metadata_stream_id = 1113
stream_id = 2
producer_id = 7
layout_version = 1
nslots = 8
shm_base_dir = "$(dir)"
shm_namespace = "tensorpool"
producer_instance_id = "alloc-producer"
header_uri = ""
max_dims = 8
announce_interval_ns = 1000000000
qos_interval_ns = 1000000000
progress_interval_ns = 250000
progress_bytes_delta = 65536

[[producer.payload_pools]]
pool_id = 1
uri = ""
stride_bytes = 4096
nslots = 8

[consumer]
aeron_dir = "/dev/shm/aeron-\${USER}"
aeron_uri = "aeron:ipc"
descriptor_stream_id = 1110
control_stream_id = 1111
qos_stream_id = 1112
stream_id = 2
consumer_id = 42
expected_layout_version = 1
max_dims = 8
mode = "STREAM"
decimation = 1
use_shm = true
supports_shm = true
supports_progress = false
max_rate_hz = 0
payload_fallback_uri = ""
shm_base_dir = "$(dir)"
allowed_base_dirs = ["$(dir)"]
require_hugepages = false
progress_interval_us = 250
progress_bytes_delta = 65536
progress_rows_delta = 0
hello_interval_ns = 1000000000
qos_interval_ns = 1000000000
""",
                )
            end

            env = Dict(ENV)
            env["AERON_DIR"] = Aeron.MediaDriver.aeron_dir(driver)
            system = load_system_config(config_path; env = env)

            mkpath(dirname(parse_shm_uri(system.producer.header_uri).path))
            for pool in system.producer.payload_pools
                mkpath(dirname(parse_shm_uri(pool.uri).path))
            end

            producer = init_producer(system.producer)
            consumer = init_consumer(system.consumer)

            payload = UInt8[1, 2, 3, 4]
            shape = Int32[4]
            strides = Int32[1]

            announce_buf = Vector{UInt8}(undef, 1024)
            announce_enc = AeronTensorPool.ShmPoolAnnounce.Encoder(Vector{UInt8})
            AeronTensorPool.ShmPoolAnnounce.wrap_and_apply_header!(announce_enc, announce_buf, 0)
            AeronTensorPool.ShmPoolAnnounce.streamId!(announce_enc, system.producer.stream_id)
            AeronTensorPool.ShmPoolAnnounce.producerId!(announce_enc, system.producer.producer_id)
            AeronTensorPool.ShmPoolAnnounce.epoch!(announce_enc, UInt64(1))
            AeronTensorPool.ShmPoolAnnounce.layoutVersion!(announce_enc, system.producer.layout_version)
            AeronTensorPool.ShmPoolAnnounce.headerNslots!(announce_enc, system.producer.nslots)
            AeronTensorPool.ShmPoolAnnounce.headerSlotBytes!(announce_enc, UInt16(HEADER_SLOT_BYTES))
            AeronTensorPool.ShmPoolAnnounce.maxDims!(announce_enc, system.producer.max_dims)
            pools = AeronTensorPool.ShmPoolAnnounce.payloadPools!(announce_enc, length(system.producer.payload_pools))
            for pool in system.producer.payload_pools
                entry = AeronTensorPool.ShmPoolAnnounce.PayloadPools.next!(pools)
                AeronTensorPool.ShmPoolAnnounce.PayloadPools.poolId!(entry, pool.pool_id)
                AeronTensorPool.ShmPoolAnnounce.PayloadPools.poolNslots!(entry, pool.nslots)
                AeronTensorPool.ShmPoolAnnounce.PayloadPools.strideBytes!(entry, pool.stride_bytes)
                AeronTensorPool.ShmPoolAnnounce.PayloadPools.regionUri!(entry, pool.uri)
            end
            AeronTensorPool.ShmPoolAnnounce.headerRegionUri!(announce_enc, system.producer.header_uri)

            announce_dec = AeronTensorPool.ShmPoolAnnounce.Decoder(Vector{UInt8})
            header = AeronTensorPool.MessageHeader.Decoder(announce_buf, 0)
            AeronTensorPool.ShmPoolAnnounce.wrap!(announce_dec, announce_buf, 0; header = header)
            @test map_from_announce!(consumer, announce_dec)
            @test consumer.mappings.header_mmap !== nothing

            desc_buf = Vector{UInt8}(undef, AeronTensorPool.FRAME_DESCRIPTOR_LEN)
            desc_enc = AeronTensorPool.FrameDescriptor.Encoder(Vector{UInt8})
            AeronTensorPool.FrameDescriptor.wrap_and_apply_header!(desc_enc, desc_buf, 0)
            desc_dec = AeronTensorPool.FrameDescriptor.Decoder(Vector{UInt8})

            try
                GC.gc()
                @test @allocated(publish_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))) == 0

                alloc_bytes = @allocated(begin
                    for i in 1:200
                        publish_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
                        AeronTensorPool.FrameDescriptor.streamId!(desc_enc, system.producer.stream_id)
                        AeronTensorPool.FrameDescriptor.epoch!(desc_enc, UInt64(1))
                        AeronTensorPool.FrameDescriptor.seq!(desc_enc, UInt64(i - 1))
                        AeronTensorPool.FrameDescriptor.headerIndex!(
                            desc_enc,
                            UInt32((i - 1) & (system.producer.nslots - 1)),
                        )
                        AeronTensorPool.FrameDescriptor.timestampNs!(desc_enc, UInt64(0))
                        AeronTensorPool.FrameDescriptor.metaVersion!(desc_enc, UInt32(0))
                        header = AeronTensorPool.MessageHeader.Decoder(desc_buf, 0)
                        AeronTensorPool.FrameDescriptor.wrap!(desc_dec, desc_buf, 0; header = header)
                        try_read_frame!(consumer, desc_dec)
                    end
                end)
                @test alloc_bytes == 0
            finally
                close_producer_state!(producer)
                close_consumer_state!(consumer)
            end
        end
    end
end
