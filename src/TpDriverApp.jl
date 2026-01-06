module TpDriverApp

include(joinpath(@__DIR__, "..", "scripts", "run_driver.jl"))

function (@main)(ARGS)
    return run_driver_main(ARGS)
end

end
