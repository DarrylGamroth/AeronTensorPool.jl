@testset "SHM URI parsing" begin
    uri = "shm:file?path=/dev/shm/tp_pool"
    parsed = parse_shm_uri(uri)
    @test parsed.path == "/dev/shm/tp_pool"
    @test parsed.require_hugepages == false

    uri_hp = "shm:file?path=/dev/hugepages/tp_pool|require_hugepages=true"
    parsed_hp = parse_shm_uri(uri_hp)
    @test parsed_hp.path == "/dev/hugepages/tp_pool"
    @test parsed_hp.require_hugepages == true

    @test_throws ArgumentError parse_shm_uri("shm:file?path=relative/path")
    @test_throws ArgumentError parse_shm_uri("shm:file?require_hugepages=true")
    @test_throws ArgumentError parse_shm_uri("shm:file?path=/dev/shm/tp|unknown=1")
    @test validate_uri(uri)
    @test !validate_uri("bad:scheme?path=/dev/shm/tp")
end
