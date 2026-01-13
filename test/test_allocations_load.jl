@testset "Allocation load checks" begin
    hdr_buf = Vector{UInt8}(undef, HEADER_SLOT_BYTES)
    slot_enc = SlotHeaderMsg.Encoder(Vector{UInt8})
    tensor_enc = TensorHeaderMsg.Encoder(Vector{UInt8})
    wrap_slot_header!(slot_enc, hdr_buf, 0)

    slot_dec = SlotHeaderMsg.Decoder(Vector{UInt8})
    tensor_dec = TensorHeaderMsg.Decoder(Vector{UInt8})
    wrap_slot_header!(slot_dec, hdr_buf, 0)

    dims = Vector{Int32}(undef, MAX_DIMS)
    strides = Vector{Int32}(undef, MAX_DIMS)
    for i in 1:MAX_DIMS
        dims[i] = i <= 4 ? Int32(i) : Int32(0)
        strides[i] = i <= 4 ? Int32(4 * i) : Int32(0)
    end

    function write_loop!(enc, dims_vec, strides_vec, iters::Int)
        for i in 1:iters
            write_slot_header!(
                enc,
                tensor_enc,
                UInt64(2),
                UInt32(3),
                UInt32(64),
                UInt32(0),
                UInt32(0),
                UInt16(1),
                Dtype.UINT8,
                MajorOrder.ROW,
                UInt8(4),
                AeronTensorPool.ProgressUnit.NONE,
                UInt32(0),
                dims_vec,
                strides_vec,
            )
        end
        return nothing
    end

    function read_loop!(dec, iters::Int)
        for _ in 1:iters
            AeronTensorPool.try_read_slot_header(dec, tensor_dec)
        end
        return nothing
    end

    write_slot_header!(
        slot_enc,
        tensor_enc,
        UInt64(2),
        UInt32(3),
        UInt32(64),
        UInt32(0),
        UInt32(0),
        UInt16(1),
        Dtype.UINT8,
        MajorOrder.ROW,
        UInt8(4),
        AeronTensorPool.ProgressUnit.NONE,
        UInt32(0),
        dims,
        strides,
    )

    @test @allocated(write_loop!(slot_enc, dims, strides, 10_000)) == 0
    @test @allocated(read_loop!(slot_dec, 10_000)) == 0

    desc_buf = Vector{UInt8}(undef, 128)
    desc_enc = FrameDescriptor.Encoder(Vector{UInt8})
    FrameDescriptor.wrap_and_apply_header!(desc_enc, desc_buf, 0)

    function desc_loop!(enc, iters::Int)
        for i in 1:iters
            FrameDescriptor.streamId!(enc, UInt32(1))
            FrameDescriptor.epoch!(enc, UInt64(2))
            FrameDescriptor.seq!(enc, UInt64(i))
            FrameDescriptor.timestampNs!(enc, UInt64(4))
            FrameDescriptor.metaVersion!(enc, UInt32(1))
            FrameDescriptor.traceId!(enc, UInt64(0))
        end
        return nothing
    end

    @test @allocated(desc_loop!(desc_enc, 10_000)) == 0
end
