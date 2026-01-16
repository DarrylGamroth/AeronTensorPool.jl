using Test

@testset "Producer progress emission" begin
    with_driver_and_client() do driver, client
        mktempdir("/dev/shm") do dir
            aeron_dir = Aeron.MediaDriver.aeron_dir(driver)
            cfg = test_producer_config(dir; aeron_dir = aeron_dir, control_stream_id = Int32(16300))
            mkpath(dirname(parse_shm_uri(cfg.header_uri).path))
            for pool in cfg.payload_pools
                mkpath(dirname(parse_shm_uri(pool.uri).path))
            end
            state = Producer.init_producer(cfg; client = client)
            sub = Aeron.add_subscription(client, cfg.aeron_uri, cfg.control_stream_id)
            try
                progress = Ref{Union{
                    NamedTuple{(:seq, :state, :bytes), Tuple{UInt64, AeronTensorPool.ShmTensorpoolControl.FrameProgressState.SbeEnum, UInt64}},
                    Nothing,
                }}(nothing)
                handler = Aeron.FragmentHandler() do _, buffer, _
                    header = MessageHeader.Decoder(buffer, 0)
                    if MessageHeader.templateId(header) == AeronTensorPool.TEMPLATE_FRAME_PROGRESS
                        dec = FrameProgress.Decoder(typeof(buffer))
                        FrameProgress.wrap!(dec, buffer, 0; header = header)
                        progress[] = (
                            seq = FrameProgress.seq(dec),
                            state = FrameProgress.state(dec),
                            bytes = FrameProgress.payloadBytesFilled(dec),
                        )
                    end
                    nothing
                end
                assembler = Aeron.FragmentAssembler(handler)

                ok = wait_for() do
                    Aeron.is_connected(state.runtime.control.pub_control)
                end
                @test ok == true

                sent = AeronTensorPool.Producer.emit_progress_complete!(state, UInt64(7), UInt64(128))
                @test sent == true

                ok = wait_for() do
                    Aeron.poll(sub, assembler, 10)
                    progress[] !== nothing
                end
                @test ok == true
                snapshot = progress[]
                snapshot === nothing && error("missing progress snapshot")
                @test snapshot.seq == UInt64(7)
                @test snapshot.bytes == UInt64(128)
                @test snapshot.state == AeronTensorPool.ShmTensorpoolControl.FrameProgressState.COMPLETE
            finally
                close(sub)
                close_producer_state!(state)
            end
        end
    end
end
