# Regenerate SBE codecs from schema definitions.
function regen_sbe()
    @info "Regenerating SBE codecs"
    @eval begin
        using SBE
        root = abspath(joinpath(@__DIR__, ".."))
        SBE.generate(
            joinpath(root, "schemas", "wire-schema.xml"),
            joinpath(root, "src", "gen", "ShmTensorpoolControl.jl");
            module_name="ShmTensorpoolControl",
        )
        SBE.generate(
            joinpath(root, "schemas", "driver-schema.xml"),
            joinpath(root, "src", "gen", "ShmTensorpoolDriver.jl");
            module_name="ShmTensorpoolDriver",
        )
        SBE.generate(
            joinpath(root, "schemas", "bridge-schema.xml"),
            joinpath(root, "src", "gen", "ShmTensorpoolBridge.jl");
            module_name="ShmTensorpoolBridge",
        )
        SBE.generate(
            joinpath(root, "schemas", "discovery-schema.xml"),
            joinpath(root, "src", "gen", "ShmTensorpoolDiscovery.jl");
            module_name="ShmTensorpoolDiscovery",
        )
    end
end

regen_sbe()
