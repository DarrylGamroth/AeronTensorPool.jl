@testset "CLI tool" begin
    uri = "shm:file?path=/dev/shm/tensorpool/test-producer/epoch-1/payload-1.pool"
    root = normpath(joinpath(@__DIR__, ".."))
    tool = joinpath(root, "scripts", "tp_tool.jl")
    cmd = `julia --project=$root $tool validate-uri $uri`
    output = readchomp(cmd)
    @test output == "true"
end
