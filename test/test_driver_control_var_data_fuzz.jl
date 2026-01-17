using Random
using Test
using UnsafeArrays

function build_truncated_consumer_hello()
    block_len = Int(ConsumerHello.sbe_block_length(ConsumerHello.Decoder))
    header_len = Int(ConsumerHello.descriptorChannel_header_length)
    buf_len = AeronTensorPool.MESSAGE_HEADER_LEN + block_len + header_len
    buf = zeros(UInt8, buf_len)
    header = MessageHeader.Encoder(buf)
    MessageHeader.blockLength!(header, UInt16(block_len))
    MessageHeader.templateId!(header, AeronTensorPool.TEMPLATE_CONSUMER_HELLO)
    MessageHeader.schemaId!(header, MessageHeader.sbe_schema_id(MessageHeader.Decoder))
    MessageHeader.version!(header, ConsumerHello.sbe_schema_version(ConsumerHello.Decoder))

    pos = AeronTensorPool.MESSAGE_HEADER_LEN + block_len
    unsafe_store!(Ptr{UInt32}(pointer(buf, pos + 1)), UInt32(buf_len))
    return buf
end

function build_truncated_shutdown_request()
    block_len = Int(ShmDriverShutdownRequest.sbe_block_length(ShmDriverShutdownRequest.Decoder))
    header_len = Int(ShmDriverShutdownRequest.token_header_length)
    buf_len = AeronTensorPool.DRIVER_MESSAGE_HEADER_LEN + block_len + header_len
    buf = zeros(UInt8, buf_len)
    header = DriverMessageHeader.Encoder(buf)
    DriverMessageHeader.blockLength!(header, UInt16(block_len))
    DriverMessageHeader.templateId!(header, AeronTensorPool.TEMPLATE_SHM_DRIVER_SHUTDOWN_REQUEST)
    DriverMessageHeader.schemaId!(header, ShmAttachRequest.sbe_schema_id(ShmAttachRequest.Decoder))
    DriverMessageHeader.version!(header, ShmDriverShutdownRequest.sbe_schema_version(ShmDriverShutdownRequest.Decoder))

    pos = AeronTensorPool.DRIVER_MESSAGE_HEADER_LEN + block_len
    unsafe_store!(Ptr{UInt32}(pointer(buf, pos + 1)), UInt32(buf_len))
    return buf
end

function build_invalid_driver_schema()
    buf = zeros(UInt8, AeronTensorPool.DRIVER_MESSAGE_HEADER_LEN + 8)
    header = DriverMessageHeader.Encoder(buf)
    DriverMessageHeader.blockLength!(header, UInt16(0))
    DriverMessageHeader.templateId!(header, AeronTensorPool.TEMPLATE_SHM_ATTACH_REQUEST)
    DriverMessageHeader.schemaId!(
        header,
        ShmAttachRequest.sbe_schema_id(ShmAttachRequest.Decoder) + UInt16(1),
    )
    DriverMessageHeader.version!(header, UInt16(1))
    return buf
end

@testset "Driver control var-data fuzz" begin
    with_driver_and_client() do media_driver, client
        base_dir = mktempdir()

        endpoints = DriverEndpoints(
            "driver-fuzz",
            Aeron.MediaDriver.aeron_dir(media_driver),
            "aeron:ipc",
            1000,
            "aeron:ipc",
            1001,
            "aeron:ipc",
            1200,
        )
        shm = DriverShmConfig(base_dir, "default", false, UInt32(4096), "660", [base_dir])
        policies = DriverPolicyConfig(
            false,
            "raw",
            UInt32(100),
            UInt32(10_000),
            UInt32(3),
            false,
            false,
            false,
            false,
            UInt32(2000),
            "secret",
        )
        profile = DriverProfileConfig(
            "raw",
            UInt32(8),
            UInt16(256),
            UInt8(8),
            [DriverPoolConfig(UInt16(1), UInt32(1024))],
        )
        streams = Dict("cam1" => DriverStreamConfig("cam1", UInt32(1001), "raw"))
        cfg = DriverConfig(
            endpoints,
            shm,
            policies,
            Dict("raw" => profile),
            streams,
        )

        driver_state = init_driver(cfg; client = client)
        try
            rng = Random.MersenneTwister(0x1c80_c4f9)
            for _ in 1:200
                choice = rand(rng, 1:3)
                buf = if choice == 1
                    build_truncated_consumer_hello()
                elseif choice == 2
                    build_truncated_shutdown_request()
                else
                    build_invalid_driver_schema()
                end
                unsafe_buf = UnsafeArrays.UnsafeArray{UInt8, 1}(pointer(buf), (length(buf),))
                @test AeronTensorPool.Driver.handle_driver_control!(driver_state, unsafe_buf) isa Bool
            end
        finally
            close_driver_state!(driver_state)
        end
    end
end
