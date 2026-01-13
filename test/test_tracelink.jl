@testset "TraceLink encoding" begin
    generator = TraceIdGenerator(1)
    id1 = next_trace_id!(generator)
    id2 = next_trace_id!(generator)
    @test id1 != 0
    @test id2 > id1

    parents = UInt64[UInt64(10), UInt64(20)]
    msg_len = AeronTensorPool.MESSAGE_HEADER_LEN +
        Int(TraceLinkSet.sbe_block_length(TraceLinkSet.Decoder)) +
        Int(TraceLinkSet.Parents.sbe_header_size(TraceLinkSet.Parents.Decoder)) +
        length(parents) * Int(TraceLinkSet.Parents.sbe_block_length(TraceLinkSet.Parents.Decoder))

    buf = Vector{UInt8}(undef, msg_len)
    enc = TraceLinkSet.Encoder(Vector{UInt8})
    TraceLinkSet.wrap_and_apply_header!(enc, buf, 0)
    ok = AeronTensorPool.Client.encode_tracelink_set!(enc, UInt32(7), UInt64(9), UInt64(11), UInt64(42), parents)
    @test ok == true

    dec = TraceLinkSet.Decoder(Vector{UInt8})
    @test decode_tracelink_set!(dec, buf) == true
    @test TraceLinkSet.streamId(dec) == UInt32(7)
    @test TraceLinkSet.epoch(dec) == UInt64(9)
    @test TraceLinkSet.seq(dec) == UInt64(11)
    @test TraceLinkSet.traceId(dec) == UInt64(42)
    group = TraceLinkSet.parents(dec)
    @test length(group) == 2
    ids = UInt64[]
    for entry in group
        push!(ids, TraceLinkSet.Parents.traceId(entry))
    end
    @test ids == parents

    TraceLinkSet.wrap_and_apply_header!(enc, buf, 0)
    @test AeronTensorPool.Client.encode_tracelink_set!(
        enc,
        UInt32(1),
        UInt64(1),
        UInt64(1),
        UInt64(0),
        parents,
    ) == false
    TraceLinkSet.wrap_and_apply_header!(enc, buf, 0)
    @test AeronTensorPool.Client.encode_tracelink_set!(
        enc,
        UInt32(1),
        UInt64(1),
        UInt64(1),
        UInt64(1),
        UInt64[],
    ) == false
    TraceLinkSet.wrap_and_apply_header!(enc, buf, 0)
    @test AeronTensorPool.Client.encode_tracelink_set!(
        enc,
        UInt32(1),
        UInt64(1),
        UInt64(1),
        UInt64(1),
        UInt64[UInt64(5), UInt64(5)],
    ) == false
end
