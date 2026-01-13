@testset "CLI tool" begin
    user = AeronTensorPool.Shm.canonical_user_name()
    uri = "shm:file?path=/dev/shm/tensorpool-$(user)/default/10000/1/1.pool"
    root = normpath(joinpath(@__DIR__, ".."))
    tool = joinpath(root, "scripts", "tp_tool.jl")
    cmd = `julia --project=$root $tool validate-uri $uri`
    output = readchomp(cmd)
    @test output == "true"
end
