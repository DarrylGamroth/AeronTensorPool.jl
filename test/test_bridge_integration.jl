@testset "Bridge rematerialization + metadata forwarding" begin
    fragment_limit = AeronTensorPool.DEFAULT_FRAGMENT_LIMIT
    message_header_len = AeronTensorPool.MESSAGE_HEADER_LEN
    DataSourceAnnounce = AeronTensorPool.DataSourceAnnounce
    DataSourceMeta = AeronTensorPool.DataSourceMeta
    template_frame_descriptor = AeronTensorPool.TEMPLATE_FRAME_DESCRIPTOR
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            aeron_dir = Aeron.MediaDriver.aeron_dir(driver)

            src_base = joinpath(dir, "src")
            dst_base = joinpath(dir, "dst")
            mkpath(src_base)
            mkpath(dst_base)

            prepare_canonical_shm_layout(
                src_base;
                namespace = "tensorpool",
                producer_instance_id = "bridge-src",
                epoch = 1,
                pool_id = 1,
            )
            prepare_canonical_shm_layout(
                dst_base;
                namespace = "tensorpool",
                producer_instance_id = "bridge-dst",
                epoch = 1,
                pool_id = 1,
            )

            src_header_uri = canonical_header_uri(src_base, "tensorpool", "bridge-src", 1)
            src_pool_uri = canonical_pool_uri(src_base, "tensorpool", "bridge-src", 1, 1)
            dst_header_uri = canonical_header_uri(dst_base, "tensorpool", "bridge-dst", 1)
            dst_pool_uri = canonical_pool_uri(dst_base, "tensorpool", "bridge-dst", 1, 1)

            src_pool = PayloadPoolConfig(UInt16(1), src_pool_uri, UInt32(4096), UInt32(8))
            dst_pool = PayloadPoolConfig(UInt16(1), dst_pool_uri, UInt32(4096), UInt32(8))

            src_config = ProducerConfig(
                aeron_dir,
                "aeron:ipc",
                Int32(1100),
                Int32(1000),
                Int32(1200),
                Int32(1300),
                UInt32(1),
                UInt32(10),
                UInt32(1),
                UInt32(8),
                src_base,
                "tensorpool",
                "bridge-src",
                src_header_uri,
                [src_pool],
                UInt8(MAX_DIMS),
                UInt64(1_000_000_000),
                UInt64(1_000_000_000),
                UInt64(250_000),
                UInt64(65536),
            )

            dst_config = ProducerConfig(
                aeron_dir,
                "aeron:ipc",
                Int32(2100),
                Int32(2000),
                Int32(2200),
                Int32(2300),
                UInt32(2),
                UInt32(20),
                UInt32(1),
                UInt32(8),
                dst_base,
                "tensorpool",
                "bridge-dst",
                dst_header_uri,
                [dst_pool],
                UInt8(MAX_DIMS),
                UInt64(1_000_000_000),
                UInt64(1_000_000_000),
                UInt64(250_000),
                UInt64(65536),
            )

            src_consumer = ConsumerSettings(
                aeron_dir,
                "aeron:ipc",
                Int32(1100),
                Int32(1000),
                Int32(1200),
                UInt32(1),
                UInt32(42),
                UInt32(1),
                UInt8(MAX_DIMS),
                Mode.STREAM,
                UInt16(1),
                UInt32(256),
                true,
                true,
                false,
                UInt16(0),
                "",
                src_base,
                [src_base],
                false,
                UInt32(250),
                UInt32(65536),
                UInt32(0),
                UInt64(1_000_000_000),
                UInt64(1_000_000_000),
                "",
                UInt32(0),
                "",
                UInt32(0),
            )

            dst_consumer = ConsumerSettings(
                aeron_dir,
                "aeron:ipc",
                Int32(2100),
                Int32(2000),
                Int32(2200),
                UInt32(2),
                UInt32(43),
                UInt32(1),
                UInt8(MAX_DIMS),
                Mode.STREAM,
                UInt16(1),
                UInt32(256),
                true,
                true,
                false,
                UInt16(0),
                "",
                dst_base,
                [dst_base],
                false,
                UInt32(250),
                UInt32(65536),
                UInt32(0),
                UInt64(1_000_000_000),
                UInt64(1_000_000_000),
                "",
                UInt32(0),
                "",
                UInt32(0),
            )

            producer_src = init_producer(src_config; client = client)
            producer_dst = init_producer(dst_config; client = client)
            consumer_src = init_consumer(src_consumer; client = client)
            consumer_dst = init_consumer(dst_consumer; client = client)

            mapping = BridgeMapping(UInt32(1), UInt32(2), "default", UInt32(2300), Int32(0), Int32(0))
            bridge_config = BridgeConfig(
                "bridge-test",
                aeron_dir,
                "aeron:ipc",
                Int32(5000),
                "aeron:ipc",
                Int32(5001),
                "aeron:ipc",
                Int32(5002),
                Int32(1300),
                UInt32(1408),
                UInt32(512),
                UInt32(65535),
                UInt32(1_048_576),
                true,
                false,
                false,
                UInt64(250_000_000),
            )

                bridge_sender = init_bridge_sender(consumer_src, bridge_config, mapping; client = client)
                bridge_receiver =
                    init_bridge_receiver(bridge_config, mapping; producer_state = producer_dst, client = client)

            src_control = make_control_assembler(consumer_src)
            dst_control = make_control_assembler(consumer_dst)

            bridge_desc = Aeron.FragmentAssembler(Aeron.FragmentHandler(bridge_sender) do st, buffer, _
                header = MessageHeader.Decoder(buffer, 0)
                if MessageHeader.templateId(header) == template_frame_descriptor
                    FrameDescriptor.wrap!(st.consumer_state.runtime.desc_decoder, buffer, 0; header = header)
                    bridge_send_frame!(st, st.consumer_state.runtime.desc_decoder)
                end
                nothing
            end)

            got_payload = Ref{Vector{UInt8}}(Vector{UInt8}())
            got_meta_announce = Ref(false)
            got_meta = Ref(false)

            dst_desc = Aeron.FragmentAssembler(Aeron.FragmentHandler(consumer_dst) do st, buffer, _
                header = MessageHeader.Decoder(buffer, 0)
                if MessageHeader.templateId(header) == template_frame_descriptor
                    FrameDescriptor.wrap!(st.runtime.desc_decoder, buffer, 0; header = header)
                    result = try_read_frame!(st, st.runtime.desc_decoder)
                    if result
                        got_payload[] = collect(payload_view(st.runtime.frame_view.payload))
                    end
                end
                nothing
            end)

            meta_ctx = Aeron.Context()
            Aeron.aeron_dir!(meta_ctx, aeron_dir)
            meta_client = Aeron.Client(meta_ctx)
            meta_sub = Aeron.add_subscription(meta_client, "aeron:ipc", Int32(2300))
            meta_announce_decoder = DataSourceAnnounce.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
            meta_meta_decoder = DataSourceMeta.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
            meta_asm = Aeron.FragmentAssembler(Aeron.FragmentHandler(consumer_dst) do _, buffer, _
                header = MessageHeader.Decoder(buffer, 0)
                template_id = MessageHeader.templateId(header)
                if template_id == DataSourceAnnounce.sbe_template_id(DataSourceAnnounce.Decoder)
                    DataSourceAnnounce.wrap!(meta_announce_decoder, buffer, 0; header = header)
                    got_meta_announce[] = DataSourceAnnounce.streamId(meta_announce_decoder) == UInt32(2300)
                elseif template_id == DataSourceMeta.sbe_template_id(DataSourceMeta.Decoder)
                    DataSourceMeta.wrap!(meta_meta_decoder, buffer, 0; header = header)
                    got_meta[] = DataSourceMeta.streamId(meta_meta_decoder) == UInt32(2300)
                end
                nothing
            end)

            announce_ready = wait_for() do
                emit_announce!(producer_src)
                emit_announce!(producer_dst)

                Aeron.poll(consumer_src.runtime.control.sub_control, src_control, fragment_limit)
                Aeron.poll(consumer_dst.runtime.control.sub_control, dst_control, fragment_limit)
                bridge_sender_do_work!(bridge_sender)
                bridge_receiver_do_work!(bridge_receiver)

                consumer_src.mappings.header_mmap !== nothing &&
                    consumer_dst.mappings.header_mmap !== nothing &&
                    bridge_receiver.have_announce
            end
            @test announce_ready

            claim = Aeron.BufferClaim()
            name = "camera-1"
            summary = "bridge-test"
            announce_len = message_header_len +
                Int(DataSourceAnnounce.sbe_block_length(DataSourceAnnounce.Decoder)) +
                4 + sizeof(name) +
                4 + sizeof(summary)
            meta_len = message_header_len +
                Int(DataSourceMeta.sbe_block_length(DataSourceMeta.Decoder)) +
                4

            sent_meta = wait_for() do
                sent_announce = try_claim_sbe!(producer_src.runtime.pub_metadata, claim, announce_len) do buf
                    enc = DataSourceAnnounce.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1})
                    DataSourceAnnounce.wrap_and_apply_header!(enc, buf, 0)
                    DataSourceAnnounce.streamId!(enc, UInt32(1))
                    DataSourceAnnounce.producerId!(enc, UInt32(10))
                    DataSourceAnnounce.epoch!(enc, UInt64(1))
                    DataSourceAnnounce.metaVersion!(enc, UInt32(7))
                    DataSourceAnnounce.name!(enc, name)
                    DataSourceAnnounce.summary!(enc, summary)
                end

                sent_meta = try_claim_sbe!(producer_src.runtime.pub_metadata, claim, meta_len) do buf
                    enc = DataSourceMeta.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1})
                    DataSourceMeta.wrap_and_apply_header!(enc, buf, 0)
                    DataSourceMeta.streamId!(enc, UInt32(1))
                    DataSourceMeta.metaVersion!(enc, UInt32(7))
                    DataSourceMeta.timestampNs!(enc, UInt64(12345))
                    DataSourceMeta.attributes!(enc, 0)
                end
                sent_announce && sent_meta
            end
            @test sent_meta

            meta_ready = wait_for() do
                bridge_sender_do_work!(bridge_sender)
                bridge_receiver_do_work!(bridge_receiver)
                Aeron.poll(meta_sub, meta_asm, fragment_limit)
                got_meta_announce[] && got_meta[]
            end
            @test meta_ready

            payload = UInt8[1, 2, 3, 4, 5]
            shape = Int32[5]
            strides = Int32[1]
            published = publish_frame!(producer_src, payload, shape, strides, Dtype.UINT8, UInt32(7))
            @test published

            bridged = wait_for() do
                Aeron.poll(consumer_src.runtime.sub_descriptor, bridge_desc, fragment_limit)
                bridge_receiver_do_work!(bridge_receiver)
                Aeron.poll(consumer_dst.runtime.sub_descriptor, dst_desc, fragment_limit)
                !isempty(got_payload[])
            end
            @test bridged
            @test got_payload[] == payload

                try
                    close(meta_sub)
                    close(meta_client)
                    close(meta_ctx)
                catch
                end
                close_consumer_state!(consumer_src)
                close_consumer_state!(consumer_dst)
                close_producer_state!(producer_src)
                close_producer_state!(producer_dst)
                try
                    close(bridge_sender.pub_payload)
                    close(bridge_sender.pub_control)
                    bridge_sender.pub_metadata === nothing || close(bridge_sender.pub_metadata)
                    close(bridge_sender.sub_control)
                    bridge_sender.sub_metadata === nothing || close(bridge_sender.sub_metadata)
                    bridge_sender.sub_qos === nothing || close(bridge_sender.sub_qos)
                catch
                end
                try
                    close(bridge_receiver.sub_payload)
                    close(bridge_receiver.sub_control)
                    bridge_receiver.sub_metadata === nothing || close(bridge_receiver.sub_metadata)
                    bridge_receiver.pub_metadata_local === nothing || close(bridge_receiver.pub_metadata_local)
                    bridge_receiver.pub_qos_local === nothing || close(bridge_receiver.pub_qos_local)
                catch
                end
        end
    end
end
