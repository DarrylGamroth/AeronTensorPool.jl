#!/usr/bin/env julia
using Aeron
using AeronTensorPool

function usage()
    println("Usage: julia --project scripts/inspect_shm_layout.jl [base_dir] [--keep]")
    println("  base_dir defaults to /dev/shm/tensorpool-inspect-<pid>")
    exit(1)
end

base_dir = "/dev/shm/tensorpool-inspect-$(getpid())"
keep = false
for arg in ARGS
    if arg == "--keep"
        keep = true
    elseif startswith(arg, "-")
        usage()
    else
        base_dir = arg
    end
end

namespace = "tensorpool"
instance_id = "inspect-$(getpid())"
epoch = 1
pool_id = UInt16(1)

header_uri = canonical_header_uri(base_dir, namespace, instance_id, epoch)
pool_uri = canonical_pool_uri(base_dir, namespace, instance_id, epoch, pool_id)

mkpath(dirname(parse_shm_uri(header_uri).path))
mkpath(dirname(parse_shm_uri(pool_uri).path))

function close_producer_state!(state::ProducerState)
    try
        close(state.runtime.pub_descriptor)
        close(state.runtime.pub_control)
        close(state.runtime.pub_qos)
        close(state.runtime.pub_metadata)
        close(state.runtime.sub_control)
        close(state.runtime.client)
        close(state.runtime.ctx)
    catch
    end
    return nothing
end

Aeron.MediaDriver.launch_embedded() do driver
    producer_cfg = ProducerConfig(
        Aeron.MediaDriver.aeron_dir(driver),
        "aeron:ipc",
        Int32(16001),
        Int32(16002),
        Int32(16003),
        Int32(16004),
        UInt32(1),
        UInt32(1),
        UInt32(1),
        UInt32(8),
        base_dir,
        namespace,
        instance_id,
        header_uri,
        [PayloadPoolConfig(pool_id, pool_uri, UInt32(4096), UInt32(8))],
        UInt8(MAX_DIMS),
        UInt64(1_000_000_000),
        UInt64(1_000_000_000),
        UInt64(250_000),
        UInt64(65536),
        false,
    )

    state = init_producer(producer_cfg)

    println("SHM layout created:")
    println("  base_dir = $(base_dir)")
    println("  header_uri = $(header_uri)")
    println("  pool_uri = $(pool_uri)")
    println("  header_path = $(parse_shm_uri(header_uri).path)")
    println("  pool_path = $(parse_shm_uri(pool_uri).path)")

    if keep
        println("Leaving SHM files on disk (--keep). Press Ctrl+C to exit.")
        while true
            sleep(1.0)
        end
    else
        println("Press Enter to clean up and exit.")
        try
            readline()
        catch
        end
    end

    close_producer_state!(state)
end
