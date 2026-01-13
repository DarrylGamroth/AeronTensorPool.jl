@testset "Allocation checks: tracelink" begin
    generator = TraceIdGenerator(1)
    next_trace_id!(generator)
    GC.gc()
    @test @allocated(next_trace_id!(generator)) == 0

    parents = UInt64[UInt64(10), UInt64(20)]
    msg_len = AeronTensorPool.TRACELINK_MESSAGE_HEADER_LEN +
        Int(TraceLinkSet.sbe_block_length(TraceLinkSet.Decoder)) +
        Int(TraceLinkSet.Parents.sbe_header_size(TraceLinkSet.Parents.Decoder)) +
        length(parents) * Int(TraceLinkSet.Parents.sbe_block_length(TraceLinkSet.Parents.Decoder))

    buf = Vector{UInt8}(undef, msg_len)
    enc = TraceLinkSet.Encoder(Vector{UInt8})
    TraceLinkSet.wrap_and_apply_header!(enc, buf, 0)
    AeronTensorPool.Client.encode_tracelink_set!(enc, UInt32(7), UInt64(9), UInt64(11), UInt64(42), parents)

    GC.gc()
    TraceLinkSet.wrap_and_apply_header!(enc, buf, 0)
    @test @allocated(AeronTensorPool.Client.encode_tracelink_set!(
        enc,
        UInt32(7),
        UInt64(9),
        UInt64(11),
        UInt64(42),
        parents,
    )) == 0
end
