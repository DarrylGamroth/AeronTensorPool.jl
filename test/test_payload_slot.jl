@testset "Payload slot helpers" begin
    stride = 64
    slots = 4
    buf = Vector{UInt8}(undef, SUPERBLOCK_SIZE + stride * slots)

    off1 = payload_slot_offset(stride, 0)
    off2 = payload_slot_offset(stride, 2)
    @test off1 == SUPERBLOCK_SIZE
    @test off2 == SUPERBLOCK_SIZE + 2 * stride

    view0 = payload_slot_view(buf, stride, 0)
    view2 = payload_slot_view(buf, stride, 2, 16)
    @test length(view0) == stride
    @test length(view2) == 16

    ptr, len = payload_slot_ptr(buf, stride, 1)
    @test len == stride
    unsafe_store!(ptr, 0x7f)
    @test buf[SUPERBLOCK_SIZE + stride + 1] == 0x7f
end
