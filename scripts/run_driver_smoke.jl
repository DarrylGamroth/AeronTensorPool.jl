#!/usr/bin/env julia
using Aeron
using AeronTensorPool

function usage()
    println("Usage: julia --project scripts/run_driver_smoke.jl")
end

function write_driver_config(path::String, aeron_dir::String, shm_dir::String)
    mkpath(shm_dir)
    open(path, "w") do io
        write(
            io,
            """
[driver]
instance_id = "driver-smoke"
aeron_dir = "$(aeron_dir)"
control_channel = "aeron:ipc"
control_stream_id = 15000
announce_channel = "aeron:ipc"
announce_stream_id = 15001
qos_channel = "aeron:ipc"
qos_stream_id = 15002

[shm]
base_dir = "$(shm_dir)"
require_hugepages = false
page_size_bytes = 4096
permissions_mode = "660"

[policies]
allow_dynamic_streams = false
default_profile = "raw"
announce_period_ms = 1000
lease_keepalive_interval_ms = 1000
lease_expiry_grace_intervals = 3

[profiles.raw]
header_nslots = 8
payload_pools = [
  { pool_id = 1, stride_bytes = 4096 }
]

[streams.cam1]
stream_id = 42
profile = "raw"
""",
        )
    end
    return nothing
end

function close_driver_state!(state::DriverState)
    try
        close(state.runtime.pub_control)
        close(state.runtime.pub_announce)
        close(state.runtime.pub_qos)
        close(state.runtime.sub_control)
        close(state.runtime.client)
        close(state.runtime.ctx)
    catch
    end
    return nothing
end

function parse_lease_id(output::String)
    for line in split(output, '\n')
        startswith(line, "lease_id=") || continue
        return parse(UInt64, split(line, "=", limit = 2)[2])
    end
    return UInt64(0)
end

if length(ARGS) > 0
    usage()
    exit(1)
end

Aeron.MediaDriver.launch_embedded() do media_driver
    mktempdir() do dir
        config_path = joinpath(dir, "driver.toml")
        shm_dir = joinpath(dir, "shm")
        aeron_dir = Aeron.MediaDriver.aeron_dir(media_driver)
        write_driver_config(config_path, aeron_dir, shm_dir)

        driver_state = init_driver(load_driver_config(config_path))
        running = Ref(true)
        driver_task = @async begin
            while running[]
                driver_do_work!(driver_state)
                yield()
            end
        end

        attach_cmd = `julia --project scripts/tp_tool.jl driver-attach $(aeron_dir) aeron:ipc 15000 7 producer 42`
        attach_out = read(attach_cmd, String)
        println(attach_out)
        lease_id = parse_lease_id(attach_out)
        lease_id != 0 || error("driver attach failed")

        keepalive_cmd =
            `julia --project scripts/tp_tool.jl driver-keepalive $(aeron_dir) aeron:ipc 15000 7 producer 42 $(lease_id)`
        keepalive_out = read(keepalive_cmd, String)
        println("keepalive=$(strip(keepalive_out))")

        detach_cmd =
            `julia --project scripts/tp_tool.jl driver-detach $(aeron_dir) aeron:ipc 15000 7 producer 42 $(lease_id)`
        detach_out = read(detach_cmd, String)
        println(detach_out)

        running[] = false
        wait(driver_task)
        close_driver_state!(driver_state)
    end
end
