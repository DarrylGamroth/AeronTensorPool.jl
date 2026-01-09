using Test

@testset "Consumer schema and template gating" begin
    with_driver_and_client() do driver, client
        consumer_cfg = ConsumerConfig(
            Aeron.MediaDriver.aeron_dir(driver),
            "aeron:ipc",
            Int32(15010),
            Int32(15011),
            Int32(15012),
            UInt32(1010),
            UInt32(42),
            UInt32(1),
            UInt8(MAX_DIMS),
            Mode.STREAM,
            UInt32(256),
            true,
            true,
            false,
            UInt16(0),
            "",
            "",
            String[],
            false,
            UInt32(250),
            UInt32(65536),
            UInt32(0),
            UInt64(1_000_000_000),
            UInt64(1_000_000_000),
            UInt64(3_000_000_000),
            "",
            UInt32(0),
            "",
            UInt32(0),
            false,
        )
        state = Consumer.init_consumer(consumer_cfg; client = client)
        try
            called = Ref(false)
            callbacks = ConsumerCallbacks(on_frame! = (_, _) -> (called[] = true))
            desc_asm = Consumer.make_descriptor_assembler(state; callbacks = callbacks)
            desc_handler = desc_asm.fragment_handler[]

            buf = Vector{UInt8}(undef, MessageHeader.sbe_encoded_length(MessageHeader.Encoder))
            header = MessageHeader.Encoder(buf)
            MessageHeader.blockLength!(header, UInt16(0))
            MessageHeader.templateId!(header, AeronTensorPool.TEMPLATE_FRAME_DESCRIPTOR)
            MessageHeader.schemaId!(header, UInt16(999))
            MessageHeader.version!(header, UInt16(1))

            Aeron.on_fragment(desc_handler)(Aeron.clientd(desc_handler), buf, C_NULL)
            @test called[] == false
            @test state.metrics.frames_ok == 0

            MessageHeader.schemaId!(header, MessageHeader.sbe_schema_id(MessageHeader.Encoder))
            MessageHeader.templateId!(header, AeronTensorPool.TEMPLATE_SHM_POOL_ANNOUNCE)
            Aeron.on_fragment(desc_handler)(Aeron.clientd(desc_handler), buf, C_NULL)
            @test called[] == false
            @test state.metrics.frames_ok == 0

            ctrl_asm = Consumer.make_control_assembler(state)
            ctrl_handler = ctrl_asm.fragment_handler[]
            MessageHeader.templateId!(header, AeronTensorPool.TEMPLATE_FRAME_DESCRIPTOR)
            Aeron.on_fragment(ctrl_handler)(Aeron.clientd(ctrl_handler), buf, C_NULL)
            @test state.mappings.header_mmap === nothing
            @test state.mappings.mapped_epoch == 0
        finally
            close_consumer_state!(state)
        end
    end
end
