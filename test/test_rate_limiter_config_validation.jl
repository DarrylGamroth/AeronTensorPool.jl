using Test

function make_rate_limiter_config(; forward_progress::Bool = false, forward_qos::Bool = false,
    source_control_stream_id::Int32 = Int32(0), dest_control_stream_id::Int32 = Int32(0),
    source_qos_stream_id::Int32 = Int32(0), dest_qos_stream_id::Int32 = Int32(0))
    return RateLimiterConfig(
        "rate-limiter-test",
        "",
        "aeron:ipc",
        "/dev/shm",
        "aeron:ipc",
        Int32(1000),
        "aeron:ipc",
        Int32(1100),
        "aeron:ipc",
        Int32(1200),
        "aeron:ipc",
        Int32(1300),
        "aeron:ipc",
        Int32(1400),
        false,
        forward_progress,
        forward_qos,
        UInt32(0),
        source_control_stream_id,
        dest_control_stream_id,
        source_qos_stream_id,
        dest_qos_stream_id,
        UInt64(1),
        UInt64(1),
        UInt64(1),
    )
end

@testset "RateLimiter forward_* validation" begin
    cfg_progress = make_rate_limiter_config(; forward_progress = true)
    @test_throws ArgumentError AeronTensorPool.Agents.RateLimiter.validate_rate_limiter_config!(cfg_progress)

    cfg_qos = make_rate_limiter_config(; forward_qos = true)
    @test_throws ArgumentError AeronTensorPool.Agents.RateLimiter.validate_rate_limiter_config!(cfg_qos)

    cfg_ok = make_rate_limiter_config(
        ;
        forward_progress = true,
        forward_qos = true,
        source_control_stream_id = Int32(2001),
        dest_control_stream_id = Int32(2002),
        source_qos_stream_id = Int32(3001),
        dest_qos_stream_id = Int32(3002),
    )
    @test AeronTensorPool.Agents.RateLimiter.validate_rate_limiter_config!(cfg_ok) === cfg_ok
end
