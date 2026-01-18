using Test
using UnsafeArrays

@testset "Bridge QoS forwarding" begin
    with_driver_and_client() do driver, client
        mapping = BridgeMapping(UInt32(11), UInt32(22), "qos", UInt32(0), Int32(6001), Int32(6002))
        bridge_cfg = BridgeConfig(
            "bridge-qos",
            Aeron.MediaDriver.aeron_dir(driver),
            "aeron:ipc",
            Int32(5100),
            "aeron:ipc",
            Int32(5101),
            "",
            Int32(0),
            Int32(0),
            UInt32(1408),
            UInt32(512),
            UInt32(1024),
            UInt32(4096),
            false,
            UInt64(250_000_000),
            false,
            true,
            false,
            false,
        )

        receiver = Bridge.init_bridge_receiver(bridge_cfg, mapping; client = client)
        sub = Aeron.add_subscription(client.aeron_client, "aeron:ipc", mapping.dest_control_stream_id)

        connected = wait_for() do
            receiver.pub_control_local !== nothing &&
                Aeron.is_connected(receiver.pub_control_local) &&
                Aeron.is_connected(sub)
        end
        @test connected

        prod_buf = Vector{UInt8}(undef, AeronTensorPool.QOS_PRODUCER_LEN)
        prod_enc = QosProducer.Encoder(Vector{UInt8})
        QosProducer.wrap_and_apply_header!(prod_enc, prod_buf, 0)
        QosProducer.streamId!(prod_enc, mapping.dest_stream_id)
        QosProducer.producerId!(prod_enc, UInt32(7))
        QosProducer.epoch!(prod_enc, UInt64(1))
        QosProducer.currentSeq!(prod_enc, UInt64(9))
        prod_dec = QosProducer.Decoder(Vector{UInt8})
        QosProducer.wrap!(prod_dec, prod_buf, 0; header = MessageHeader.Decoder(prod_buf, 0))

        cons_buf = Vector{UInt8}(undef, AeronTensorPool.QOS_CONSUMER_LEN)
        cons_enc = QosConsumer.Encoder(Vector{UInt8})
        QosConsumer.wrap_and_apply_header!(cons_enc, cons_buf, 0)
        QosConsumer.streamId!(cons_enc, mapping.dest_stream_id)
        QosConsumer.consumerId!(cons_enc, UInt32(9))
        QosConsumer.epoch!(cons_enc, UInt64(1))
        QosConsumer.lastSeqSeen!(cons_enc, UInt64(8))
        QosConsumer.dropsGap!(cons_enc, UInt64(1))
        QosConsumer.dropsLate!(cons_enc, UInt64(2))
        QosConsumer.mode!(cons_enc, Mode.STREAM)
        cons_dec = QosConsumer.Decoder(Vector{UInt8})
        QosConsumer.wrap!(cons_dec, cons_buf, 0; header = MessageHeader.Decoder(cons_buf, 0))

        @test Bridge.bridge_publish_qos_producer!(receiver, prod_dec)
        @test Bridge.bridge_publish_qos_consumer!(receiver, cons_dec)

        got_prod = Ref(false)
        got_cons = Ref(false)
        prod_dec_sub = QosProducer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
        cons_dec_sub = QosConsumer.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})

        handler = Aeron.FragmentHandler((_, buffer, _) -> begin
            header = MessageHeader.Decoder(buffer, 0)
            template_id = MessageHeader.templateId(header)
            if template_id == AeronTensorPool.Core.TEMPLATE_QOS_PRODUCER
                QosProducer.wrap!(prod_dec_sub, buffer, 0; header = header)
                got_prod[] = QosProducer.streamId(prod_dec_sub) == mapping.dest_stream_id &&
                    QosProducer.producerId(prod_dec_sub) == UInt32(7) &&
                    QosProducer.currentSeq(prod_dec_sub) == UInt64(9)
            elseif template_id == AeronTensorPool.Core.TEMPLATE_QOS_CONSUMER
                QosConsumer.wrap!(cons_dec_sub, buffer, 0; header = header)
                got_cons[] = QosConsumer.streamId(cons_dec_sub) == mapping.dest_stream_id &&
                    QosConsumer.consumerId(cons_dec_sub) == UInt32(9) &&
                    QosConsumer.lastSeqSeen(cons_dec_sub) == UInt64(8)
            end
            nothing
        end)
        assembler = Aeron.FragmentAssembler(handler)

        delivered = wait_for() do
            Aeron.poll(sub, assembler, 10)
            got_prod[] && got_cons[]
        end
        @test delivered

        close(sub)
    end
end
