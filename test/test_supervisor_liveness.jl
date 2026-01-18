using Test
using Clocks

@testset "Supervisor liveness tracking" begin
    with_driver_and_client() do driver, client
        uri = "aeron:ipc"
        control_stream = Int32(12201)
        qos_stream = Int32(12202)
        stream_id = UInt32(7)

        supervisor_cfg = SupervisorConfig(
            Aeron.MediaDriver.aeron_dir(driver),
            uri,
            control_stream,
            qos_stream,
            stream_id,
            UInt64(1_000),
            UInt64(500),
        )
        supervisor_state = Supervisor.init_supervisor(supervisor_cfg; client = client)

        try
            now_ns = UInt64(10_000)
            Clocks.update!(supervisor_state.clock, Int64(now_ns))
            announce = build_shm_pool_announce(
                stream_id = stream_id,
                producer_id = UInt32(11),
                epoch = UInt64(3),
            )
            Supervisor.handle_shm_pool_announce!(supervisor_state, announce.dec)

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
            ConsumerHello.descriptorStreamId!(hello_enc, UInt32(0))
            ConsumerHello.controlStreamId!(hello_enc, UInt32(0))
            ConsumerHello.descriptorChannel_length!(hello_enc, 0)
            ConsumerHello.controlChannel_length!(hello_enc, 0)
            hello_header = MessageHeader.Decoder(hello_buf, 0)
            hello_dec = ConsumerHello.Decoder(Vector{UInt8})
            ConsumerHello.wrap!(hello_dec, hello_buf, 0; header = hello_header)

            hello_ns = now_ns + UInt64(100)
            Clocks.update!(supervisor_state.clock, Int64(hello_ns))
            Supervisor.handle_consumer_hello!(supervisor_state, hello_dec)

            prod_info = supervisor_state.tracking.producers[UInt32(11)]
            cons_info = supervisor_state.tracking.consumers[UInt32(21)]
            @test prod_info.last_announce_ns == now_ns
            @test prod_info.liveness_timer.last_ns == now_ns
            @test cons_info.last_hello_ns == hello_ns
            @test cons_info.liveness_timer.last_ns == hello_ns

            stale_ns = hello_ns + supervisor_state.config.liveness_timeout_ns + UInt64(1)
            @test AeronTensorPool.Timers.expired(prod_info.liveness_timer, stale_ns)
            @test AeronTensorPool.Timers.expired(cons_info.liveness_timer, stale_ns)

            prev_count = supervisor_state.tracking.liveness_count
            work = Supervisor.poll_timers!(supervisor_state, stale_ns)
            @test work > 0
            @test supervisor_state.tracking.liveness_count == prev_count + 1
        finally
            close_supervisor_state!(supervisor_state)
        end
    end
end
