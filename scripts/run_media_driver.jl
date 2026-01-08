#!/usr/bin/env julia
using Aeron
using Logging

Base.exit_on_sigint(false)

function usage()
    println("Usage: julia --project scripts/run_media_driver.jl [aeron_dir]")
end

function main()
    if length(ARGS) > 1
        usage()
        return 1
    end
    aeron_dir = length(ARGS) == 1 ? ARGS[1] : get(ENV, "AERON_DIR", "")
    ctx = Aeron.MediaDriver.Context()
    isempty(aeron_dir) || Aeron.MediaDriver.aeron_dir!(ctx, aeron_dir)
    Aeron.MediaDriver.launch(ctx) do driver
        actual_dir = Aeron.MediaDriver.aeron_dir(driver)
        @info "Media driver running" aeron_dir = actual_dir
        try
            wait(Condition())
        catch e
            if e isa InterruptException
                @info "Media driver shutting down"
            else
                @error "Media driver error" exception = (e, catch_backtrace())
            end
        end
    end
    return 0
end

main()
