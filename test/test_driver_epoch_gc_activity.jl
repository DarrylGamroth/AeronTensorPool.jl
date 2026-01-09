using Test
using AeronTensorPool

@testset "Driver epoch GC uses activity timestamp" begin
    with_driver_and_client() do _driver, client
        mktempdir() do base_dir
            config_path = joinpath(base_dir, "driver_gc.toml")
            open(config_path, "w") do io
                write(io, """
[driver]
instance_id = \"driver-gc\"
control_channel = \"aeron:ipc\"
control_stream_id = 1000
announce_channel = \"aeron:ipc\"
announce_stream_id = 1001
qos_channel = \"aeron:ipc\"
qos_stream_id = 1200

[shm]
base_dir = \"$(base_dir)\"
require_hugepages = false
page_size_bytes = 4096
permissions_mode = \"660\"
allowed_base_dirs = [\"$(base_dir)\"]

[policies]
allow_dynamic_streams = false
default_profile = \"camera\"
announce_period_ms = 1000
lease_keepalive_interval_ms = 1000
lease_expiry_grace_intervals = 3
epoch_gc_enabled = true
epoch_gc_keep = 1
epoch_gc_min_age_ns = 1

[profiles.camera]
header_nslots = 8
payload_pools = [ { pool_id = 1, stride_bytes = 1024 } ]

[streams.cam1]
stream_id = 10000
profile = \"camera\"
""")
            end

            cfg = load_driver_config(config_path)
            state = Driver.init_driver(cfg; client = client)
            try
                now_ns = UInt64(time_ns())
                root = joinpath(base_dir, "stream-10000", "driver-gc")
                epoch1 = joinpath(root, "epoch-1")
                epoch2 = joinpath(root, "epoch-2")
                mkpath(epoch1)
                mkpath(epoch2)

                header1 = joinpath(epoch1, "header.ring")
                header2 = joinpath(epoch2, "header.ring")
                buf = zeros(UInt8, SUPERBLOCK_SIZE)
                enc = ShmRegionSuperblock.Encoder(Vector{UInt8})

                wrap_superblock!(enc, buf, 0)
                write_superblock!(
                    enc,
                    SuperblockFields(
                        MAGIC_TPOLSHM1,
                        UInt32(1),
                        UInt64(1),
                        UInt32(10000),
                        RegionType.HEADER_RING,
                        UInt16(0),
                        UInt32(8),
                        UInt32(HEADER_SLOT_BYTES),
                        UInt32(0),
                        UInt64(999999),
                        now_ns - 10_000_000_000,
                        now_ns - 10_000_000_000,
                    ),
                )
                open(header1, "w") do io
                    write(io, buf)
                end

                wrap_superblock!(enc, buf, 0)
                write_superblock!(
                    enc,
                    SuperblockFields(
                        MAGIC_TPOLSHM1,
                        UInt32(1),
                        UInt64(2),
                        UInt32(10000),
                        RegionType.HEADER_RING,
                        UInt16(0),
                        UInt32(8),
                        UInt32(HEADER_SLOT_BYTES),
                        UInt32(0),
                        UInt64(getpid()),
                        now_ns,
                        now_ns,
                    ),
                )
                open(header2, "w") do io
                    write(io, buf)
                end

                removed = Driver.gc_orphan_epochs_for_stream!(state, UInt32(10000), now_ns)
                @test removed == 1
                @test !isdir(epoch1)
                @test isdir(epoch2)
            finally
                close_driver_state!(state)
            end
        end
    end
end
