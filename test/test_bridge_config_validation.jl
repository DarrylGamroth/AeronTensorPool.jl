@testset "Bridge config validation" begin
    base = BridgeConfig(
        "bridge",
        "",
        "aeron:ipc",
        Int32(5000),
        "aeron:ipc",
        Int32(5001),
        "aeron:ipc",
        Int32(5002),
        Int32(5003),
        UInt32(1408),
        UInt32(512),
        UInt32(1024),
        UInt32(1_048_576),
        UInt64(250_000_000),
        true,
        true,
        true,
    )
    mapping = BridgeMapping(UInt32(1), UInt32(2), "profile", UInt32(0), Int32(6001), Int32(6002))
    @test validate_bridge_config(base, [mapping])

    bad_control = BridgeConfig(
        base.instance_id,
        base.aeron_dir,
        base.payload_channel,
        base.payload_stream_id,
        "",
        Int32(0),
        base.metadata_channel,
        base.metadata_stream_id,
        base.source_metadata_stream_id,
        base.mtu_bytes,
        base.chunk_bytes,
        base.max_chunk_bytes,
        base.max_payload_bytes,
        base.assembly_timeout_ns,
        base.forward_metadata,
        base.forward_qos,
        base.forward_progress,
    )
    @test_throws BridgeConfigError validate_bridge_config(bad_control, [mapping])

    too_large_chunk = BridgeConfig(
        base.instance_id,
        base.aeron_dir,
        base.payload_channel,
        base.payload_stream_id,
        base.control_channel,
        base.control_stream_id,
        base.metadata_channel,
        base.metadata_stream_id,
        base.source_metadata_stream_id,
        UInt32(1408),
        UInt32(2000),
        base.max_chunk_bytes,
        base.max_payload_bytes,
        base.assembly_timeout_ns,
        base.forward_metadata,
        base.forward_qos,
        base.forward_progress,
    )
    @test_throws BridgeConfigError validate_bridge_config(too_large_chunk, [mapping])

    loop_a = BridgeMapping(UInt32(1), UInt32(2), "profile", UInt32(0), Int32(6001), Int32(6002))
    loop_b = BridgeMapping(UInt32(2), UInt32(1), "profile", UInt32(0), Int32(6003), Int32(6004))
    @test validate_bridge_config(base, [loop_a, loop_b])
end
