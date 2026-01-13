@testset "Seqlock encoding" begin
    buf = zeros(UInt8, 8)
    ptr = Ptr{UInt64}(pointer(buf))
    seqlock_begin_write!(ptr, UInt64(5))
    @test unsafe_load(ptr) == UInt64(10)
    seqlock_commit_write!(ptr, UInt64(5))
    @test unsafe_load(ptr) == UInt64(11)
    @test seqlock_is_committed(unsafe_load(ptr))
    @test seqlock_sequence(unsafe_load(ptr)) == UInt64(5)
end
