@testset "Allocation checks: SHM URI parsing" begin
    uri = "shm:file?path=/dev/shm/tensorpool/test/epoch-1/header.ring|require_hugepages=true"
    alloc_parse = @allocated(parse_shm_uri(uri))
    alloc_validate = @allocated(validate_uri(uri))
    @test alloc_parse <= 1024
    @test alloc_validate <= 1024
end
