using Test

@testset "Driver config loader" begin
    cfg = load_driver_config(joinpath(@__DIR__, "..", "docs", "examples", "driver_camera_example.toml"))

    @test cfg.endpoints.control_stream_id == 1000
    @test cfg.endpoints.announce_stream_id == 1001
    @test cfg.policies.allow_dynamic_streams == true
    @test cfg.policies.shutdown_token == ""
    @test haskey(cfg.profiles, "raw_profile")
    @test haskey(cfg.streams, "cam1")

    profile = cfg.profiles["raw_profile"]
    @test profile.header_nslots == 1024
    @test profile.header_slot_bytes == 256
    @test !isempty(profile.payload_pools)

    stream = cfg.streams["cam1"]
    @test stream.stream_id == 1001
    @test stream.profile == "raw_profile"
end
