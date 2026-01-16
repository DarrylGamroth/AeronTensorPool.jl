using Random

@testset "SHM URI parsing" begin
    user = AeronTensorPool.Shm.canonical_user_name()
    uri = "shm:file?path=/dev/shm/tensorpool-$(user)/default/10000/1/1.pool"
    parsed = parse_shm_uri(uri)
    @test parsed.path == "/dev/shm/tensorpool-$(user)/default/10000/1/1.pool"
    @test parsed.require_hugepages == false

    uri_hp = "shm:file?path=/dev/hugepages/tensorpool-$(user)/default/10000/1/1.pool|require_hugepages=true"
    parsed_hp = parse_shm_uri(uri_hp)
    @test parsed_hp.path == "/dev/hugepages/tensorpool-$(user)/default/10000/1/1.pool"
    @test parsed_hp.require_hugepages == true

    @test_throws ShmUriError parse_shm_uri("shm:file?path=relative/path")
    @test_throws ShmUriError parse_shm_uri("shm:file?require_hugepages=true")
    @test_throws ShmUriError parse_shm_uri(
        "shm:file?path=/dev/shm/tensorpool-$(user)/default/10000/1/tp|unknown=1",
    )
    @test validate_uri(uri)
    @test !validate_uri("bad:scheme?path=/dev/shm/tensorpool-$(user)/default/10000/1/tp")

    rng = Random.MersenneTwister(0x2b11_9f7a)
    for _ in 1:200
        path = "/dev/shm/tp-" * randstring(rng, 8)
        require_hp = rand(rng, Bool)
        if require_hp
            uri = "shm:file?path=$(path)|require_hugepages=true"
        else
            uri = "shm:file?path=$(path)"
        end
        parsed = parse_shm_uri(uri)
        @test parsed.path == path
        @test parsed.require_hugepages == require_hp
        @test validate_uri(uri)
    end

    for _ in 1:200
        mode = rand(rng, 1:3)
        if mode == 1
            uri = "shm:file?require_hugepages=true"
        elseif mode == 2
            uri = "shm:file?path=relative/" * randstring(rng, 6)
        else
            uri = "shm:file?path=/dev/shm/" * randstring(rng, 6) * "|oops=" * randstring(rng, 4)
        end
        @test_throws ShmUriError parse_shm_uri(uri)
        @test !validate_uri(uri)
    end
end
