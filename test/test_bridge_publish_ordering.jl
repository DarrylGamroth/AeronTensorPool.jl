using Test

@testset "Bridge publishes descriptor after commit" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            base = joinpath(dir, "dst")
            mkpath(base)
            prepare_canonical_shm_layout(
                base;
                namespace = "tensorpool",
                stream_id = 11,
                epoch = 1,
                pool_id = 1,
            )
            header_uri = canonical_header_uri(base, "tensorpool", 11, 1)
            pool_uri = canonical_pool_uri(base, "tensorpool", 11, 1, 1)

            pool = PayloadPoolConfig(UInt16(1), pool_uri, UInt32(4096), UInt32(8))
            producer_cfg = ProducerConfig(
                Aeron.MediaDriver.aeron_dir(driver),
                "aeron:ipc",
                Int32(17210),
                Int32(17211),
                Int32(17212),
                Int32(17213),
                UInt32(11),
                UInt32(110),
                UInt32(1),
                UInt32(8),
                base,
                "tensorpool",
                "bridge-order",
                header_uri,
                [pool],
                UInt8(MAX_DIMS),
                UInt64(1_000_000_000),
                UInt64(1_000_000_000),
                UInt64(250_000),
                UInt64(65536),
                false,
            )

            producer_state = Producer.init_producer(producer_cfg; client = client)
            try
                mapping = BridgeMapping(UInt32(11), UInt32(11), "default", UInt32(0), Int32(0), Int32(0))
                bridge_cfg = BridgeConfig(
                    "bridge-order",
                    Aeron.MediaDriver.aeron_dir(driver),
                    "aeron:ipc",
                    Int32(17220),
                    "aeron:ipc",
                    Int32(17221),
                    "",
                    Int32(0),
                    Int32(0),
                    UInt32(1408),
                    UInt32(512),
                    UInt32(1024),
                    UInt32(2048),
                    UInt64(1_000_000_000),
                    false,
                    false,
                    false,
                )
                receiver = Bridge.init_bridge_receiver(bridge_cfg, mapping; producer_state = producer_state, client = client)

                sub = Aeron.add_subscription(client, "aeron:ipc", Int32(17210))
                ok = wait_for(; timeout = 3.0) do
                    Aeron.is_connected(producer_state.runtime.pub_descriptor) && Aeron.is_connected(sub)
                end
                @test ok

                receiver.assembly.seq = UInt64(5)
                receiver.assembly.epoch = UInt64(1)

                dims = ntuple(i -> i == 1 ? Int32(16) : Int32(0), AeronTensorPool.MAX_DIMS)
                strides = ntuple(_ -> Int32(0), AeronTensorPool.MAX_DIMS)
                header = SlotHeader(
                    UInt64(5) << 1,
                    UInt64(0),
                    UInt32(1),
                    UInt32(16),
                    UInt32(0),
                    UInt32(0),
                    UInt16(1),
                    TensorHeader(
                        Dtype.UINT8,
                        MajorOrder.ROW,
                        UInt8(1),
                        UInt8(0),
                        AeronTensorPool.ProgressUnit.NONE,
                        UInt32(0),
                        dims,
                        strides,
                    ),
                )
                payload = Vector{UInt8}(undef, 16)
                fill!(payload, 0x2a)

                ok = Bridge.bridge_rematerialize!(receiver, header, payload)
                @test ok

                received = Ref(false)
                desc_seq = Ref(UInt64(0))
                desc_handler = Aeron.FragmentHandler(nothing) do _, buffer, _
                    header = MessageHeader.Decoder(buffer, 0)
                    MessageHeader.templateId(header) == AeronTensorPool.TEMPLATE_FRAME_DESCRIPTOR || return nothing
                    desc = FrameDescriptor.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
                    FrameDescriptor.wrap!(desc, buffer, 0; header = header)
                    desc_seq[] = FrameDescriptor.seq(desc)
                    received[] = true
                    return nothing
                end
                desc_asm = Aeron.FragmentAssembler(desc_handler)

                ok = wait_for(; timeout = 3.0) do
                    Aeron.poll(sub, desc_asm, Int32(10))
                    received[]
                end
                @test ok
                @test desc_seq[] == UInt64(5)

                header_index = UInt32(desc_seq[] & (UInt64(producer_state.config.nslots) - 1))
                header_offset = header_slot_offset(header_index)
                commit_ptr = header_commit_ptr_from_offset(producer_state.mappings.header_mmap, header_offset)
                commit = seqlock_read_begin(commit_ptr)
                @test seqlock_is_committed(commit)
                @test seqlock_sequence(commit) == desc_seq[]
            finally
                close_producer_state!(producer_state)
            end
        end
    end
end
