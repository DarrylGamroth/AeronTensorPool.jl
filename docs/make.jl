using Pkg

Pkg.activate(@__DIR__)
Pkg.develop(PackageSpec(path = joinpath(@__DIR__, "..")))
Pkg.instantiate()

using Documenter
using AeronTensorPool

makedocs(
    modules = [AeronTensorPool],
    sitename = "AeronTensorPool.jl",
    pages = [
        "Home" => "index.md",
    ],
)
