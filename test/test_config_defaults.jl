@testset "Config defaults" begin
    consumer_cfg = AeronTensorPool.default_consumer_config()
    @test consumer_cfg.shm_base_dir == "/dev/shm"
    @test consumer_cfg.allowed_base_dirs == ["/dev/shm"]

    driver_cfg = load_driver_config(joinpath(@__DIR__, "..", "config", "driver_camera_example.toml"))
    @test driver_cfg.shm.base_dir == "/dev/shm"
    @test driver_cfg.shm.allowed_base_dirs == ["/dev/shm"]
end
