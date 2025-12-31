@testset "Supervisor integration handlers" begin
    with_embedded_driver() do driver
        control_stream = Int32(12101)
        qos_stream = Int32(12102)
        uri = "aeron:ipc"
        stream_id = UInt32(7)

        supervisor_cfg = SupervisorConfig(
            Aeron.MediaDriver.aeron_dir(driver),
            uri,
            control_stream,
            qos_stream,
            stream_id,
            UInt64(2_000_000_000),
            UInt64(200_000_000),
        )
        supervisor_state = init_supervisor(supervisor_cfg)
        ctrl_asm = make_control_assembler(supervisor_state)
        qos_asm = AeronTensorPool.make_qos_assembler(supervisor_state)

        pub_control = Aeron.add_publication(supervisor_state.client, uri, control_stream)
        pub_qos = Aeron.add_publication(supervisor_state.client, uri, qos_stream)
        sub_cfg = nothing

        try
            announce_buf = Vector{UInt8}(undef, 1024)
            announce_enc = AeronTensorPool.ShmPoolAnnounce.Encoder(Vector{UInt8})
            AeronTensorPool.ShmPoolAnnounce.wrap_and_apply_header!(announce_enc, announce_buf, 0)
            AeronTensorPool.ShmPoolAnnounce.streamId!(announce_enc, stream_id)
            AeronTensorPool.ShmPoolAnnounce.producerId!(announce_enc, UInt32(11))
            AeronTensorPool.ShmPoolAnnounce.epoch!(announce_enc, UInt64(3))
            AeronTensorPool.ShmPoolAnnounce.layoutVersion!(announce_enc, UInt32(1))
            AeronTensorPool.ShmPoolAnnounce.headerNslots!(announce_enc, UInt32(8))
            AeronTensorPool.ShmPoolAnnounce.headerSlotBytes!(announce_enc, UInt16(HEADER_SLOT_BYTES))
            AeronTensorPool.ShmPoolAnnounce.maxDims!(announce_enc, UInt8(MAX_DIMS))
            pools = AeronTensorPool.ShmPoolAnnounce.payloadPools!(announce_enc, 1)
            pool = AeronTensorPool.ShmPoolAnnounce.PayloadPools.next!(pools)
            AeronTensorPool.ShmPoolAnnounce.PayloadPools.poolId!(pool, UInt16(1))
            AeronTensorPool.ShmPoolAnnounce.PayloadPools.regionUri!(
                pool,
                "shm:file?path=/dev/shm/tensorpool/test-producer/epoch-3/payload-1.pool",
            )
            AeronTensorPool.ShmPoolAnnounce.PayloadPools.poolNslots!(pool, UInt32(8))
            AeronTensorPool.ShmPoolAnnounce.PayloadPools.strideBytes!(pool, UInt32(4096))
            AeronTensorPool.ShmPoolAnnounce.headerRegionUri!(
                announce_enc,
                "shm:file?path=/dev/shm/tensorpool/test-producer/epoch-3/header.ring",
            )
            Aeron.offer(pub_control, view(announce_buf, 1:sbe_message_length(announce_enc)))

        hello_buf = Vector{UInt8}(undef, 256)
        hello_enc = ConsumerHello.Encoder(Vector{UInt8})
        ConsumerHello.wrap_and_apply_header!(hello_enc, hello_buf, 0)
        ConsumerHello.streamId!(hello_enc, stream_id)
        ConsumerHello.consumerId!(hello_enc, UInt32(21))
        ConsumerHello.supportsShm!(hello_enc, AeronTensorPool.ShmTensorpoolControl.Bool_.TRUE)
        ConsumerHello.supportsProgress!(hello_enc, AeronTensorPool.ShmTensorpoolControl.Bool_.FALSE)
        ConsumerHello.mode!(hello_enc, Mode.STREAM)
        ConsumerHello.maxRateHz!(hello_enc, UInt16(0))
        ConsumerHello.expectedLayoutVersion!(hello_enc, UInt32(1))
        Aeron.offer(pub_control, view(hello_buf, 1:sbe_message_length(hello_enc)))

        ok = wait_for() do
            Aeron.poll(supervisor_state.sub_control, ctrl_asm, AeronTensorPool.DEFAULT_FRAGMENT_LIMIT) > 0
        end
        @test ok
        @test haskey(supervisor_state.producers, UInt32(11))
        @test haskey(supervisor_state.consumers, UInt32(21))

        qos_p_buf = Vector{UInt8}(undef, 256)
        qos_p_enc = QosProducer.Encoder(Vector{UInt8})
        QosProducer.wrap_and_apply_header!(qos_p_enc, qos_p_buf, 0)
        QosProducer.streamId!(qos_p_enc, stream_id)
        QosProducer.producerId!(qos_p_enc, UInt32(11))
        QosProducer.epoch!(qos_p_enc, UInt64(3))
        QosProducer.currentSeq!(qos_p_enc, UInt64(42))
        Aeron.offer(pub_qos, view(qos_p_buf, 1:sbe_message_length(qos_p_enc)))

        qos_c_buf = Vector{UInt8}(undef, 256)
        qos_c_enc = QosConsumer.Encoder(Vector{UInt8})
        QosConsumer.wrap_and_apply_header!(qos_c_enc, qos_c_buf, 0)
        QosConsumer.streamId!(qos_c_enc, stream_id)
        QosConsumer.consumerId!(qos_c_enc, UInt32(21))
        QosConsumer.epoch!(qos_c_enc, UInt64(3))
        QosConsumer.lastSeqSeen!(qos_c_enc, UInt64(41))
        QosConsumer.dropsGap!(qos_c_enc, UInt64(2))
        QosConsumer.dropsLate!(qos_c_enc, UInt64(1))
        QosConsumer.mode!(qos_c_enc, Mode.STREAM)
        Aeron.offer(pub_qos, view(qos_c_buf, 1:sbe_message_length(qos_c_enc)))

        ok_qos = wait_for() do
            Aeron.poll(supervisor_state.sub_qos, qos_asm, AeronTensorPool.DEFAULT_FRAGMENT_LIMIT) > 0
        end
        @test ok_qos
        @test supervisor_state.producers[UInt32(11)].current_seq == UInt64(42)
        @test supervisor_state.consumers[UInt32(21)].drops_gap == UInt64(2)
        @test supervisor_state.consumers[UInt32(21)].drops_late == UInt64(1)

        ok_step = wait_for() do
            supervisor_do_work!(supervisor_state, ctrl_asm, qos_asm) > 0
        end
        @test ok_step

        got_cfg = Ref(false)
        cfg_decoder = ConsumerConfigMsg.Decoder(Vector{UInt8})
        cfg_scratch = Vector{UInt8}(undef, 256)
        cfg_handler = Aeron.FragmentHandler((cfg_decoder, cfg_scratch)) do st, buffer, _
            dec, scratch = st
            msg_len = length(buffer)
            msg_len <= length(scratch) || return nothing
            copyto!(scratch, 1, buffer, 1, msg_len)
            header = MessageHeader.Decoder(scratch, 0)
            if MessageHeader.templateId(header) == AeronTensorPool.TEMPLATE_CONSUMER_CONFIG
                ConsumerConfigMsg.wrap!(dec, scratch, 0; header = header)
                got_cfg[] = (ConsumerConfigMsg.consumerId(dec) == UInt32(21))
            end
            nothing
        end
        cfg_asm = Aeron.FragmentAssembler(cfg_handler)
        sub_cfg = Aeron.add_subscription(supervisor_state.client, uri, control_stream)

        emit_consumer_config!(supervisor_state, UInt32(21); use_shm = false, mode = Mode.LATEST)

        ok_cfg = wait_for() do
            Aeron.poll(sub_cfg, cfg_asm, AeronTensorPool.DEFAULT_FRAGMENT_LIMIT) > 0
        end
        @test ok_cfg
        @test got_cfg[]
        finally
            if sub_cfg !== nothing
                try
                    close(sub_cfg)
                catch
                end
            end
            try
                close(pub_control)
                close(pub_qos)
            catch
            end
            close_supervisor_state!(supervisor_state)
        end
    end
end
