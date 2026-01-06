module TpToolApp

include(joinpath(@__DIR__, "..", "scripts", "tp_tool.jl"))

function (@main)(ARGS)
    return tp_tool_main(ARGS)
end

end
