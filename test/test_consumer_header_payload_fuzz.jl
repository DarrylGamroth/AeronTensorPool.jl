using Random
using Test

@testset "Consumer header/payload validation fuzz" begin
    with_driver_and_client() do driver, client
        cfg = test_consumer_config(
            "/dev/shm";
            aeron_dir = Aeron.MediaDriver.aeron_dir(driver),
            stream_id = UInt32(10000),
            consumer_id = UInt32(2),
        )
        state = Consumer.init_consumer(cfg; client = client)
        try
            nslots = 8
            stride = UInt32(64)
            header_mmap = zeros(UInt8, SUPERBLOCK_SIZE + HEADER_SLOT_BYTES * nslots)
            payload_mmap = zeros(UInt8, SUPERBLOCK_SIZE + Int(stride) * nslots)
            state.mappings.header_mmap = header_mmap
            state.mappings.mapped_nslots = UInt32(nslots)
            state.mappings.mapped_epoch = UInt64(1)
            state.mappings.pool_stride_bytes[UInt16(1)] = stride
            state.mappings.payload_mmaps[UInt16(1)] = payload_mmap
            state.mappings.last_commit_words = fill(UInt64(0), nslots)

            slot_enc = SlotHeaderMsg.Encoder(Vector{UInt8})
            tensor_enc = TensorHeaderMsg.Encoder(Vector{UInt8})
            dims = vcat(Int32(4), zeros(Int32, MAX_DIMS - 1))
            strides = vcat(Int32(0), zeros(Int32, MAX_DIMS - 1))
            rng = Random.MersenneTwister(0x90b1_2a0f)

            for i in 1:200
                seq = UInt64(i)
                header_index = UInt32(seq & UInt64(nslots - 1))
                header_offset = header_slot_offset(header_index)
                wrap_slot_header!(slot_enc, header_mmap, header_offset)
                write_slot_header!(
                    slot_enc,
                    tensor_enc,
                    seq,
                    UInt32(0),
                    UInt32(16),
                    header_index,
                    UInt32(0),
                    UInt16(1),
                    Dtype.UINT8,
                    MajorOrder.ROW,
                    UInt8(1),
                    AeronTensorPool.ProgressUnit.NONE,
                    UInt32(0),
                    dims,
                    strides,
                )

                case = rand(rng, 1:7)
                if case == 1
                    SlotHeaderMsg.payloadSlot!(slot_enc, UInt32(nslots))
                elseif case == 2
                    SlotHeaderMsg.payloadSlot!(slot_enc, header_index == 0 ? UInt32(1) : UInt32(0))
                elseif case == 3
                    SlotHeaderMsg.payloadOffset!(slot_enc, UInt32(1))
                elseif case == 4
                    SlotHeaderMsg.valuesLenBytes!(slot_enc, stride + UInt32(1))
                elseif case == 5
                    SlotHeaderMsg.poolId!(slot_enc, UInt16(2))
                elseif case == 6
                    header_pos = SlotHeaderMsg.sbe_position(slot_enc) - AeronTensorPool.TENSOR_HEADER_LEN
                    TensorHeaderMsg.wrap!(tensor_enc, header_mmap, header_pos)
                    TensorHeaderMsg.dtype!(tensor_enc, Dtype.UNKNOWN)
                elseif case == 7
                    header_pos = SlotHeaderMsg.sbe_position(slot_enc) - AeronTensorPool.TENSOR_HEADER_LEN
                    TensorHeaderMsg.wrap!(tensor_enc, header_mmap, header_pos)
                    TensorHeaderMsg.ndims!(tensor_enc, UInt8(0))
                end

                commit_ptr = header_commit_ptr_from_offset(header_mmap, header_offset)
                if case == 7 && rand(rng, Bool)
                    seqlock_commit_write!(commit_ptr, seq + 1)
                else
                    seqlock_commit_write!(commit_ptr, seq)
                end

                (_, desc_dec) = build_frame_descriptor(
                    stream_id = cfg.stream_id,
                    epoch = UInt64(1),
                    seq = seq,
                    timestamp_ns = UInt64(0),
                    meta_version = UInt32(1),
                    trace_id = UInt64(0),
                )
                @test !Consumer.try_read_frame!(state, desc_dec)
            end
        finally
            close_consumer_state!(state)
        end
    end
end
