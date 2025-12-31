@testset "SHM URI parsing" begin
    uri = "shm:file?path=/dev/shm/tensorpool/test-producer/epoch-1/payload-1.pool"
    parsed = parse_shm_uri(uri)
    @test parsed.path == "/dev/shm/tensorpool/test-producer/epoch-1/payload-1.pool"
    @test parsed.require_hugepages == false

    uri_hp = "shm:file?path=/dev/hugepages/tensorpool/test-producer/epoch-1/payload-1.pool|require_hugepages=true"
    parsed_hp = parse_shm_uri(uri_hp)
    @test parsed_hp.path == "/dev/hugepages/tensorpool/test-producer/epoch-1/payload-1.pool"
    @test parsed_hp.require_hugepages == true

    @test_throws ShmUriError parse_shm_uri("shm:file?path=relative/path")
    @test_throws ShmUriError parse_shm_uri("shm:file?require_hugepages=true")
    @test_throws ShmUriError parse_shm_uri(
        "shm:file?path=/dev/shm/tensorpool/test-producer/epoch-1/tp|unknown=1",
    )
    @test validate_uri(uri)
    @test !validate_uri("bad:scheme?path=/dev/shm/tensorpool/test-producer/epoch-1/tp")
end
