using Test
using UnsafeArrays

@testset "RateLimiter forward progress and QoS" begin
    with_driver_and_client() do media_driver, client
        base_dir = mktempdir()

        endpoints = AeronTensorPool.DriverEndpoints(
            "rate-limiter-forward",
            Aeron.MediaDriver.aeron_dir(media_driver),
            "aeron:ipc",
            1000,
            "aeron:ipc",
            1100,
            "aeron:ipc",
            1200,
        )
        shm = AeronTensorPool.DriverShmConfig(base_dir, "default", false, UInt32(4096), "660", [base_dir])
        policies = AeronTensorPool.DriverPolicyConfig(
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
            "",
        )
        profile = AeronTensorPool.DriverProfileConfig(
            "raw",
            UInt32(8),
            UInt16(256),
            UInt8(8),
            [AeronTensorPool.DriverPoolConfig(UInt16(1), UInt32(1024))],
        )
        streams = Dict(
            "src" => AeronTensorPool.DriverStreamConfig("src", UInt32(10001), "raw"),
            "dest" => AeronTensorPool.DriverStreamConfig("dest", UInt32(10002), "raw"),
        )
        cfg = AeronTensorPool.DriverConfig(
            endpoints,
            shm,
            policies,
            Dict("raw" => profile),
            streams,
        )

        driver_state = AeronTensorPool.init_driver(cfg; client = client)

        rl_cfg = AeronTensorPool.RateLimiterConfig(
            "rate-limiter-forward",
            endpoints.aeron_dir,
            "aeron:ipc",
            base_dir,
            endpoints.control_channel,
            endpoints.control_stream_id,
            "aeron:ipc",
            Int32(1100),
            "aeron:ipc",
            endpoints.control_stream_id,
            "aeron:ipc",
            endpoints.qos_stream_id,
            "aeron:ipc",
            Int32(1300),
            false,
            true,
            true,
            UInt32(0),
            Int32(2001),
            Int32(2002),
            Int32(3001),
            Int32(3002),
            UInt64(1_000_000_000),
            UInt64(5_000_000_000),
            UInt64(1_000_000_000),
        )
        mapping = AeronTensorPool.RateLimiterMapping(UInt32(10001), UInt32(10002), UInt32(0), UInt32(0))
        rl_state = AeronTensorPool.init_rate_limiter(
            rl_cfg,
            [mapping];
            client = client,
            driver_work_fn = () -> AeronTensorPool.driver_do_work!(driver_state),
        )

        progress_pub = Aeron.add_publication(client, "aeron:ipc", rl_cfg.source_control_stream_id)
        progress_sub = Aeron.add_subscription(client, "aeron:ipc", rl_cfg.dest_control_stream_id)
        qos_pub = Aeron.add_publication(client, "aeron:ipc", rl_cfg.source_qos_stream_id)
        qos_sub = Aeron.add_subscription(client, "aeron:ipc", rl_cfg.dest_qos_stream_id)

        connected = wait_for() do
            Aeron.is_connected(progress_pub) && Aeron.is_connected(progress_sub) &&
                Aeron.is_connected(qos_pub) && Aeron.is_connected(qos_sub)
        end
        @test connected

        progress_claim = Aeron.BufferClaim()
        progress_enc = AeronTensorPool.FrameProgress.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1})
        progress_sent = AeronTensorPool.with_claimed_buffer!(progress_pub, progress_claim, AeronTensorPool.FRAME_PROGRESS_LEN) do buf
            AeronTensorPool.FrameProgress.wrap_and_apply_header!(progress_enc, buf, 0)
            AeronTensorPool.FrameProgress.streamId!(progress_enc, mapping.source_stream_id)
            AeronTensorPool.FrameProgress.epoch!(progress_enc, UInt64(1))
            AeronTensorPool.FrameProgress.seq!(progress_enc, UInt64(9))
            AeronTensorPool.FrameProgress.payloadBytesFilled!(progress_enc, UInt64(5))
            AeronTensorPool.FrameProgress.state!(
                progress_enc,
                AeronTensorPool.ShmTensorpoolControl.FrameProgressState.COMPLETE,
            )
        end
        @test progress_sent

        qos_claim = Aeron.BufferClaim()
        qos_prod_enc = AeronTensorPool.QosProducer.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1})
        qos_prod_sent = AeronTensorPool.with_claimed_buffer!(qos_pub, qos_claim, AeronTensorPool.QOS_PRODUCER_LEN) do buf
            AeronTensorPool.QosProducer.wrap_and_apply_header!(qos_prod_enc, buf, 0)
            AeronTensorPool.QosProducer.streamId!(qos_prod_enc, mapping.source_stream_id)
            AeronTensorPool.QosProducer.producerId!(qos_prod_enc, UInt32(7))
            AeronTensorPool.QosProducer.epoch!(qos_prod_enc, UInt64(1))
            AeronTensorPool.QosProducer.currentSeq!(qos_prod_enc, UInt64(11))
        end
        @test qos_prod_sent

        qos_cons_enc = AeronTensorPool.QosConsumer.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1})
        qos_cons_sent = AeronTensorPool.with_claimed_buffer!(qos_pub, qos_claim, AeronTensorPool.QOS_CONSUMER_LEN) do buf
            AeronTensorPool.QosConsumer.wrap_and_apply_header!(qos_cons_enc, buf, 0)
            AeronTensorPool.QosConsumer.streamId!(qos_cons_enc, mapping.source_stream_id)
            AeronTensorPool.QosConsumer.consumerId!(qos_cons_enc, UInt32(9))
            AeronTensorPool.QosConsumer.epoch!(qos_cons_enc, UInt64(1))
            AeronTensorPool.QosConsumer.lastSeqSeen!(qos_cons_enc, UInt64(10))
            AeronTensorPool.QosConsumer.dropsGap!(qos_cons_enc, UInt64(1))
            AeronTensorPool.QosConsumer.dropsLate!(qos_cons_enc, UInt64(2))
            AeronTensorPool.QosConsumer.mode!(qos_cons_enc, AeronTensorPool.Mode.STREAM)
        end
        @test qos_cons_sent

        progress_seen = Ref(false)
        qos_prod_seen = Ref(false)
        qos_cons_seen = Ref(false)

        progress_dec = AeronTensorPool.FrameProgress.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
        progress_handler = Aeron.FragmentHandler(progress_dec) do dec, buffer, _
            header = AeronTensorPool.MessageHeader.Decoder(buffer, 0)
            if AeronTensorPool.MessageHeader.templateId(header) == AeronTensorPool.Core.TEMPLATE_FRAME_PROGRESS
                AeronTensorPool.FrameProgress.wrap!(dec, buffer, 0; header = header)
                progress_seen[] = AeronTensorPool.FrameProgress.streamId(dec) == mapping.dest_stream_id &&
                    AeronTensorPool.FrameProgress.seq(dec) == UInt64(9) &&
                    AeronTensorPool.FrameProgress.payloadBytesFilled(dec) == UInt64(5)
            end
            nothing
        end
        progress_asm = Aeron.FragmentAssembler(progress_handler)

        qos_prod_dec = AeronTensorPool.QosProducer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
        qos_cons_dec = AeronTensorPool.QosConsumer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
        qos_handler = Aeron.FragmentHandler(nothing) do _, buffer, _
            header = AeronTensorPool.MessageHeader.Decoder(buffer, 0)
            template_id = AeronTensorPool.MessageHeader.templateId(header)
            if template_id == AeronTensorPool.Core.TEMPLATE_QOS_PRODUCER
                AeronTensorPool.QosProducer.wrap!(qos_prod_dec, buffer, 0; header = header)
                qos_prod_seen[] = AeronTensorPool.QosProducer.streamId(qos_prod_dec) == mapping.dest_stream_id &&
                    AeronTensorPool.QosProducer.producerId(qos_prod_dec) == UInt32(7) &&
                    AeronTensorPool.QosProducer.currentSeq(qos_prod_dec) == UInt64(11)
            elseif template_id == AeronTensorPool.Core.TEMPLATE_QOS_CONSUMER
                AeronTensorPool.QosConsumer.wrap!(qos_cons_dec, buffer, 0; header = header)
                qos_cons_seen[] = AeronTensorPool.QosConsumer.streamId(qos_cons_dec) == mapping.dest_stream_id &&
                    AeronTensorPool.QosConsumer.consumerId(qos_cons_dec) == UInt32(9) &&
                    AeronTensorPool.QosConsumer.lastSeqSeen(qos_cons_dec) == UInt64(10)
            end
            nothing
        end
        qos_asm = Aeron.FragmentAssembler(qos_handler)

        forwarded = wait_for() do
            AeronTensorPool.driver_do_work!(driver_state)
            AeronTensorPool.rate_limiter_do_work!(rl_state)
            Aeron.poll(progress_sub, progress_asm, 10)
            Aeron.poll(qos_sub, qos_asm, 10)
            progress_seen[] && qos_prod_seen[] && qos_cons_seen[]
        end
        @test forwarded

        close_driver_state!(driver_state)
    end
end
