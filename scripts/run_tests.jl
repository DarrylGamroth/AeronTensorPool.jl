using Pkg

include(joinpath(@__DIR__, "check_spec_lock.jl"))

Pkg.test()
