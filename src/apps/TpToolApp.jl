module TpToolApp

using ..Core
using ..Shm
using ..Control
using ..Driver
using ..Client
using ..DiscoveryClient
using ..AeronUtils

include(joinpath(@__DIR__, "..", "..", "scripts", "tp_tool.jl"))

function (@main)(ARGS)
    return tp_tool_main(ARGS)
end

end
