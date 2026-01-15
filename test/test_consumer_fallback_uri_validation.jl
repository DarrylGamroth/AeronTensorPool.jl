@testset "Consumer fallback URI validation" begin
    with_driver_and_client() do driver, client
        consumer_cfg = ConsumerConfig(
            Aeron.MediaDriver.aeron_dir(driver),
            "aeron:ipc",
            Int32(1410),
            Int32(1411),
            Int32(1412),
            UInt32(7),
            UInt32(17),
            UInt32(1),
            UInt8(MAX_DIMS),
            Mode.STREAM,
            UInt32(0),
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
            base_len = AeronTensorPool.MESSAGE_HEADER_LEN +
                Int(ConsumerConfigMsg.sbe_block_length(ConsumerConfigMsg.Decoder)) +
                Int(ConsumerConfigMsg.payloadFallbackUri_header_length) +
                Int(ConsumerConfigMsg.descriptorChannel_header_length) +
                Int(ConsumerConfigMsg.controlChannel_header_length)
            max_uri_len = max(ncodeunits("bad:scheme"), ncodeunits("aeron:udp?endpoint=127.0.0.1:14000"))
            buf = Vector{UInt8}(undef, base_len + max_uri_len)
            enc = ConsumerConfigMsg.Encoder(Vector{UInt8})
            dec = ConsumerConfigMsg.Decoder(Vector{UInt8})

            function apply_config(uri::AbstractString)
                ConsumerConfigMsg.wrap_and_apply_header!(enc, buf, 0)
                AeronTensorPool.encode_consumer_config!(
                    enc,
                    consumer_cfg.stream_id,
                    consumer_cfg.consumer_id;
                    use_shm = true,
                    mode = Mode.STREAM,
                    descriptor_stream_id = UInt32(0),
                    control_stream_id = UInt32(0),
                    payload_fallback_uri = uri,
                    descriptor_channel = "",
                    control_channel = "",
                )
                header = MessageHeader.Decoder(buf, 0)
                ConsumerConfigMsg.wrap!(dec, buf, 0; header = header)
                return Consumer.apply_consumer_config!(state, dec)
            end

            @test apply_config("bad:scheme")
            @test state.config.payload_fallback_uri == ""

            good_uri = "aeron:udp?endpoint=127.0.0.1:14000"
            @test apply_config(good_uri)
            @test state.config.payload_fallback_uri == good_uri
        finally
            close_consumer_state!(state)
        end
    end
end
