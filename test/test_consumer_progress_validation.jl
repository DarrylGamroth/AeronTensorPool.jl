using Test
using Aeron
using AeronTensorPool
using AeronTensorPool.Consumer

@testset "Consumer progress validation" begin
    with_driver_and_client() do driver, client
        cfg = test_consumer_config(
            "/dev/shm";
            aeron_dir = Aeron.MediaDriver.aeron_dir(driver),
            stream_id = UInt32(10000),
            consumer_id = UInt32(1),
        )
        state = Consumer.init_consumer(cfg; client = client)
        try
            state.config.supports_progress = true
            nslots = 8
            header_mmap = zeros(UInt8, SUPERBLOCK_SIZE + HEADER_SLOT_BYTES * nslots)
            state.mappings.header_mmap = header_mmap
            state.mappings.mapped_nslots = UInt32(nslots)
            state.mappings.progress_last_frame = fill(UInt64(0), nslots)
            state.mappings.progress_last_bytes = fill(UInt64(0), nslots)

            header_index = UInt32(0)
            header_offset = header_slot_offset(header_index)
            commit_ptr = header_commit_ptr_from_offset(header_mmap, header_offset)
            seq = UInt64(5)

            slot_enc = SlotHeaderMsg.Encoder(Vector{UInt8})
            tensor_enc = TensorHeaderMsg.Encoder(Vector{UInt8})
            wrap_slot_header!(slot_enc, header_mmap, header_offset)
            seqlock_begin_write!(commit_ptr, seq)
            write_slot_header!(
                slot_enc,
                tensor_enc,
                UInt64(0),
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
                Int32[16],
                Int32[1],
            )
            seqlock_commit_write!(commit_ptr, seq)

            buf = Vector{UInt8}(undef, AeronTensorPool.FRAME_PROGRESS_LEN)
            enc = FrameProgress.Encoder(Vector{UInt8})
            FrameProgress.wrap_and_apply_header!(enc, buf, 0)
            FrameProgress.streamId!(enc, cfg.stream_id)
            FrameProgress.epoch!(enc, UInt64(1))
            FrameProgress.frameId!(enc, seq)
            FrameProgress.headerIndex!(enc, header_index)
            FrameProgress.payloadBytesFilled!(enc, UInt64(8))
            FrameProgress.state!(enc, AeronTensorPool.ShmTensorpoolControl.FrameProgressState.PROGRESS)

            dec = FrameProgress.Decoder(Vector{UInt8})
            FrameProgress.wrap!(dec, buf, 0; header = AeronTensorPool.MessageHeader.Decoder(buf, 0))
            @test Consumer.handle_frame_progress!(state, dec)

            FrameProgress.payloadBytesFilled!(enc, UInt64(4))
            FrameProgress.wrap!(dec, buf, 0; header = AeronTensorPool.MessageHeader.Decoder(buf, 0))
            @test !Consumer.handle_frame_progress!(state, dec)

            FrameProgress.payloadBytesFilled!(enc, UInt64(32))
            FrameProgress.wrap!(dec, buf, 0; header = AeronTensorPool.MessageHeader.Decoder(buf, 0))
            @test !Consumer.handle_frame_progress!(state, dec)
        finally
            close_consumer_state!(state)
        end
    end
end
