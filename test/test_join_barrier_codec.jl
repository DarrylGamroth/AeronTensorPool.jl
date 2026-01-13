using Test
using AeronTensorPool
using UnsafeArrays

const Merge = AeronTensorPool.ShmTensorpoolMerge

@testset "JoinBarrier codec roundtrip" begin
    codec = JoinBarrierCodec()

    seq_rules = SequenceMergeRule[
        SequenceMergeRule(UInt32(1), Merge.MergeRuleType.OFFSET, Int32(0), nothing),
        SequenceMergeRule(UInt32(2), Merge.MergeRuleType.WINDOW, nothing, UInt32(4)),
    ]
    seq_map = SequenceMergeMap(UInt32(9), UInt64(2), UInt64(50), seq_rules)
    seq_buf = Vector{UInt8}(undef, 256)
    seq_unsafe = UnsafeArrays.UnsafeArray{UInt8, 1}(pointer(seq_buf), (length(seq_buf),))
    seq_len = encode_sequence_merge_map_announce!(codec.seq_announce_encoder, seq_unsafe, seq_map)
    @test seq_len > 0
    seq_header = Merge.MessageHeader.Decoder(seq_unsafe, 0)
    Merge.SequenceMergeMapAnnounce.wrap!(codec.seq_announce_decoder, seq_unsafe, 0; header = seq_header)
    seq_decoded = decode_sequence_merge_map_announce(codec.seq_announce_decoder)
    @test seq_decoded.out_stream_id == seq_map.out_stream_id
    @test seq_decoded.epoch == seq_map.epoch
    @test seq_decoded.stale_timeout_ns == seq_map.stale_timeout_ns
    @test length(seq_decoded.rules) == length(seq_map.rules)
    @test seq_decoded.rules[1].input_stream_id == seq_map.rules[1].input_stream_id
    @test seq_decoded.rules[2].window_size == seq_map.rules[2].window_size

    ts_rules = TimestampMergeRule[
        TimestampMergeRule(
            UInt32(3),
            Merge.MergeTimeRuleType.OFFSET_NS,
            Merge.TimestampSource.FRAME_DESCRIPTOR,
            Int64(0),
            nothing,
        ),
    ]
    ts_map = TimestampMergeMap(
        UInt32(7),
        UInt64(3),
        UInt64(100),
        Merge.ClockDomain.MONOTONIC,
        UInt64(10),
        ts_rules,
    )
    ts_buf = Vector{UInt8}(undef, 256)
    ts_unsafe = UnsafeArrays.UnsafeArray{UInt8, 1}(pointer(ts_buf), (length(ts_buf),))
    ts_len = encode_timestamp_merge_map_announce!(codec.ts_announce_encoder, ts_unsafe, ts_map)
    @test ts_len > 0
    ts_header = Merge.MessageHeader.Decoder(ts_unsafe, 0)
    Merge.TimestampMergeMapAnnounce.wrap!(codec.ts_announce_decoder, ts_unsafe, 0; header = ts_header)
    ts_decoded = decode_timestamp_merge_map_announce(codec.ts_announce_decoder)
    @test ts_decoded.out_stream_id == ts_map.out_stream_id
    @test ts_decoded.epoch == ts_map.epoch
    @test ts_decoded.stale_timeout_ns == ts_map.stale_timeout_ns
    @test ts_decoded.clock_domain == ts_map.clock_domain
    @test ts_decoded.lateness_ns == ts_map.lateness_ns
    @test length(ts_decoded.rules) == length(ts_map.rules)
    @test ts_decoded.rules[1].timestamp_source == ts_map.rules[1].timestamp_source
end
