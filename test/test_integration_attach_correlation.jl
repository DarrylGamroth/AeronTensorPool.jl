using Test

@testset "Driver attach correlation matching and purge" begin
    with_embedded_driver() do driver
        Aeron.Context() do context
            Aeron.aeron_dir!(context, Aeron.MediaDriver.aeron_dir(driver))
            Aeron.Client(context) do client
                control_channel = "aeron:ipc"
                control_stream_id = Int32(15010)
                driver_pub = Aeron.add_publication(client, control_channel, control_stream_id)
                state = init_driver_client(
                    client,
                    control_channel,
                    control_stream_id,
                    UInt32(55),
                    DriverRole.CONSUMER;
                    attach_purge_interval_ns = UInt64(1_000_000_000),
                )

                ok = wait_for() do
                    Aeron.is_connected(driver_pub) && Aeron.is_connected(state.sub)
                end
                @test ok

                buf = Vector{UInt8}(undef, 2048)
                enc = ShmAttachResponse.Encoder(Vector{UInt8})

                function send_attach_response!(correlation_id::Int64)
                    ShmAttachResponse.wrap_and_apply_header!(enc, buf, 0)
                    ShmAttachResponse.correlationId!(enc, correlation_id)
                    ShmAttachResponse.code!(enc, DriverResponseCode.OK)
                    ShmAttachResponse.leaseId!(enc, UInt64(123))
                    ShmAttachResponse.leaseExpiryTimestampNs!(enc, UInt64(456))
                    ShmAttachResponse.streamId!(enc, UInt32(42))
                    ShmAttachResponse.epoch!(enc, UInt64(1))
                    ShmAttachResponse.layoutVersion!(enc, UInt32(1))
                    ShmAttachResponse.headerNslots!(enc, UInt32(8))
                    ShmAttachResponse.headerSlotBytes!(enc, UInt16(HEADER_SLOT_BYTES))
                    ShmAttachResponse.maxDims!(enc, UInt8(MAX_DIMS))
                    ShmAttachResponse.headerRegionUri!(enc, "shm:file?path=/tmp/header")
                    pools = ShmAttachResponse.payloadPools!(enc, 1)
                    entry = ShmAttachResponse.PayloadPools.next!(pools)
                    ShmAttachResponse.PayloadPools.poolId!(entry, UInt16(1))
                    ShmAttachResponse.PayloadPools.poolNslots!(entry, UInt32(8))
                    ShmAttachResponse.PayloadPools.strideBytes!(entry, UInt32(4096))
                    ShmAttachResponse.PayloadPools.regionUri!(entry, "shm:file?path=/tmp/pool")
                    ShmAttachResponse.errorMessage!(enc, "")
                    Aeron.offer(driver_pub, buf)
                    return nothing
                end

                send_attach_response!(Int64(101))
                send_attach_response!(Int64(202))

                now_ns = UInt64(100)
                driver_client_do_work!(state, now_ns)

                @test length(state.poller.attach_by_correlation) == 2
                attach = poll_attach!(state, Int64(202), now_ns)
                @test attach !== nothing
                @test attach.correlation_id == Int64(202)
                @test length(state.poller.attach_by_correlation) == 1

                driver_client_do_work!(state, now_ns + UInt64(1_000_000_001))
                @test isempty(state.poller.attach_by_correlation)
            end
        end
    end
end
