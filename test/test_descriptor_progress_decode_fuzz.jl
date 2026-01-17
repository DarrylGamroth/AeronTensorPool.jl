using Random
using Test
using UnsafeArrays

@testset "Descriptor/progress decode fuzz" begin
    with_driver_and_client() do driver, client
        cfg = test_consumer_config(
            "/dev/shm";
            aeron_dir = Aeron.MediaDriver.aeron_dir(driver),
            stream_id = UInt32(10000),
            consumer_id = UInt32(1),
        )
        state = Consumer.init_consumer(cfg; client = client)
        try
            nslots = 8
            stride = UInt32(256)
            header_mmap = zeros(UInt8, SUPERBLOCK_SIZE + HEADER_SLOT_BYTES * nslots)
            payload_mmap = zeros(UInt8, SUPERBLOCK_SIZE + Int(stride) * nslots)
            state.mappings.header_mmap = header_mmap
            state.mappings.mapped_nslots = UInt32(nslots)
            state.mappings.mapped_epoch = UInt64(1)
            state.mappings.pool_stride_bytes[UInt16(1)] = stride
            state.mappings.payload_mmaps[UInt16(1)] = payload_mmap
            state.mappings.last_commit_words = fill(UInt64(0), nslots)
            state.mappings.progress_last_frame = fill(UInt64(0), nslots)
            state.mappings.progress_last_bytes = fill(UInt64(0), nslots)
            state.config.supports_progress = true

            slot_enc = SlotHeaderMsg.Encoder(Vector{UInt8})
            tensor_enc = TensorHeaderMsg.Encoder(Vector{UInt8})
            dims = vcat(Int32(16), zeros(Int32, MAX_DIMS - 1))
            strides = vcat(Int32(1), zeros(Int32, MAX_DIMS - 1))

            seq = UInt64(1)
            header_index = UInt32(seq & UInt64(nslots - 1))
            header_offset = header_slot_offset(header_index)
            commit_ptr = header_commit_ptr_from_offset(header_mmap, header_offset)
            wrap_slot_header!(slot_enc, header_mmap, header_offset)
            seqlock_begin_write!(commit_ptr, seq)
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
            seqlock_commit_write!(commit_ptr, seq)

            desc_buf = Vector{UInt8}(undef, AeronTensorPool.FRAME_DESCRIPTOR_LEN)
            desc_unsafe = UnsafeArrays.UnsafeArray{UInt8, 1}(pointer(desc_buf), (length(desc_buf),))
            desc_enc = FrameDescriptor.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1})
            FrameDescriptor.wrap_and_apply_header!(desc_enc, desc_unsafe, 0)
            FrameDescriptor.streamId!(desc_enc, cfg.stream_id)
            FrameDescriptor.epoch!(desc_enc, UInt64(1))
            FrameDescriptor.seq!(desc_enc, seq)
            FrameDescriptor.timestampNs!(desc_enc, UInt64(0))
            FrameDescriptor.metaVersion!(desc_enc, UInt32(0))
            FrameDescriptor.traceId!(desc_enc, UInt64(0))

            desc_asm = Consumer.make_descriptor_assembler(state)
            desc_handler = desc_asm.fragment_handler[]
            Aeron.on_fragment(desc_handler)(Aeron.clientd(desc_handler), desc_unsafe, C_NULL)
            @test state.metrics.frames_ok == 1

            prog_buf = Vector{UInt8}(undef, AeronTensorPool.FRAME_PROGRESS_LEN)
            prog_unsafe = UnsafeArrays.UnsafeArray{UInt8, 1}(pointer(prog_buf), (length(prog_buf),))
            prog_enc = FrameProgress.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1})
            FrameProgress.wrap_and_apply_header!(prog_enc, prog_unsafe, 0)
            FrameProgress.streamId!(prog_enc, cfg.stream_id)
            FrameProgress.epoch!(prog_enc, UInt64(1))
            FrameProgress.seq!(prog_enc, seq)
            FrameProgress.payloadBytesFilled!(prog_enc, UInt64(8))
            FrameProgress.state!(
                prog_enc,
                AeronTensorPool.ShmTensorpoolControl.FrameProgressState.PROGRESS,
            )
            prog_dec = FrameProgress.Decoder(Vector{UInt8})
            FrameProgress.wrap!(prog_dec, prog_buf, 0; header = MessageHeader.Decoder(prog_buf, 0))
            @test FrameProgress.seq(prog_dec) == seq
            @test FrameProgress.payloadBytesFilled(prog_dec) == UInt64(8)
            Consumer.handle_frame_progress!(state, prog_dec)

            rng = Random.MersenneTwister(0x4f91_2c77)
            for i in 1:200
                seq = UInt64(i + 1)
                header_index = UInt32(seq & UInt64(nslots - 1))
                header_offset = header_slot_offset(header_index)
                commit_ptr = header_commit_ptr_from_offset(header_mmap, header_offset)
                wrap_slot_header!(slot_enc, header_mmap, header_offset)
                seqlock_begin_write!(commit_ptr, seq)
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
                seqlock_commit_write!(commit_ptr, seq)

                FrameDescriptor.wrap_and_apply_header!(desc_enc, desc_unsafe, 0)
                FrameDescriptor.streamId!(desc_enc, cfg.stream_id)
                FrameDescriptor.epoch!(desc_enc, UInt64(1))
                FrameDescriptor.seq!(desc_enc, seq)
                FrameDescriptor.timestampNs!(desc_enc, UInt64(0))
                FrameDescriptor.metaVersion!(desc_enc, UInt32(0))
                FrameDescriptor.traceId!(desc_enc, UInt64(0))

                mutate = rand(rng, 1:4)
                if mutate == 1
                    header = MessageHeader.Encoder(desc_unsafe, 0)
                    MessageHeader.schemaId!(header, MessageHeader.sbe_schema_id(MessageHeader.Decoder) + UInt16(1))
                elseif mutate == 2
                    header = MessageHeader.Encoder(desc_unsafe, 0)
                    MessageHeader.templateId!(header, AeronTensorPool.TEMPLATE_FRAME_PROGRESS)
                end
                Aeron.on_fragment(desc_handler)(Aeron.clientd(desc_handler), desc_unsafe, C_NULL)
            end

            ctrl_asm = Consumer.make_control_assembler(state)
            ctrl_handler = ctrl_asm.fragment_handler[]
            for i in 1:200
                seq = UInt64(i + 1)
                FrameProgress.wrap_and_apply_header!(prog_enc, prog_unsafe, 0)
                FrameProgress.streamId!(prog_enc, cfg.stream_id)
                FrameProgress.epoch!(prog_enc, UInt64(1))
                FrameProgress.seq!(prog_enc, seq)
                FrameProgress.payloadBytesFilled!(prog_enc, UInt64(rand(rng, 0:32)))
                FrameProgress.state!(
                    prog_enc,
                    AeronTensorPool.ShmTensorpoolControl.FrameProgressState.PROGRESS,
                )
                if rand(rng, 1:5) == 1
                    header = MessageHeader.Encoder(prog_unsafe, 0)
                    MessageHeader.schemaId!(header, MessageHeader.sbe_schema_id(MessageHeader.Decoder) + UInt16(1))
                end
                Aeron.on_fragment(ctrl_handler)(Aeron.clientd(ctrl_handler), prog_unsafe, C_NULL)
            end

            @test state.metrics.frames_ok >= 1
        finally
            close_consumer_state!(state)
        end
    end
end
