@testset "Allocation checks: seqlock helpers" begin
    buf = Vector{UInt8}(undef, 8)
    ptr = Ptr{UInt64}(pointer(buf, 1))

    @test @allocated(seqlock_begin_write!(ptr, UInt64(1))) == 0
    @test @allocated(seqlock_commit_write!(ptr, UInt64(1))) == 0
    @test @allocated(seqlock_read_begin(ptr)) == 0
    @test @allocated(seqlock_read_end(ptr)) == 0
    @test @allocated(seqlock_is_write_in_progress(UInt64(0))) == 0
    @test @allocated(seqlock_frame_id(UInt64(0))) == 0
end
