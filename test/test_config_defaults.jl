@testset "Config defaults" begin
    consumer_cfg = AeronTensorPool.default_consumer_config()
    @test consumer_cfg.shm_base_dir == "/dev/shm"
    @test consumer_cfg.allowed_base_dirs == ["/dev/shm"]
    @test consumer_cfg.control_stream_id == 1000
    @test consumer_cfg.descriptor_stream_id == 1100
    @test consumer_cfg.qos_stream_id == 1200
    @test consumer_cfg.hello_interval_ns == UInt64(1_000_000_000)
    @test consumer_cfg.qos_interval_ns == UInt64(1_000_000_000)

    driver_cfg = load_driver_config(joinpath(@__DIR__, "..", "config", "driver_camera_example.toml"))
    @test driver_cfg.shm.base_dir == "/dev/shm"
    @test driver_cfg.shm.allowed_base_dirs == ["/dev/shm"]

    producer_cfg = AeronTensorPool.default_producer_config()
    @test producer_cfg.control_stream_id == 1000
    @test producer_cfg.descriptor_stream_id == 1100
    @test producer_cfg.qos_stream_id == 1200
    @test producer_cfg.metadata_stream_id == 1300
    @test producer_cfg.announce_interval_ns == UInt64(1_000_000_000)
    @test producer_cfg.qos_interval_ns == UInt64(1_000_000_000)
end
