using Test
using Aeron
using Clocks
using StringViews
using UnsafeArrays

@testset "Discovery response caps results to max_results" begin
    with_embedded_driver() do driver
        with_client(driver = driver) do client
            request_channel = "aeron:ipc"
            request_stream_id = Int32(6100)
            response_channel = "aeron:ipc"
            response_stream_id = UInt32(6101)
            announce_channel = "aeron:ipc"
            announce_stream_id = Int32(6102)
            metadata_channel = "aeron:ipc"
            metadata_stream_id = Int32(6103)

            config = DiscoveryConfig(
                request_channel,
                request_stream_id,
                announce_channel,
                announce_stream_id,
                metadata_channel,
                metadata_stream_id,
                "driver-cap",
                "aeron:ipc",
                UInt32(6104),
                UInt32(1),
                UInt64(1_000_000_000),
                UInt32(65536),
                AeronTensorPool.DISCOVERY_MAX_TAGS_PER_ENTRY_DEFAULT,
                AeronTensorPool.DISCOVERY_MAX_POOLS_PER_ENTRY_DEFAULT,
            )
            state = AeronTensorPool.Agents.Discovery.init_discovery_provider(config; client = client)
            try
                request_asm = AeronTensorPool.Agents.Discovery.make_request_assembler(state)
                announce_asm = AeronTensorPool.Agents.Discovery.make_announce_assembler(state)
                Clocks.fetch!(state.clock)

                announce_a = build_shm_pool_announce(
                    stream_id = UInt32(6100),
                    producer_id = UInt32(1),
                    epoch = UInt64(1),
                    layout_version = UInt32(1),
                    nslots = UInt32(8),
                    header_uri = "shm:file?path=/dev/shm/tp_header_a",
                    payload_entries = NamedTuple[],
                )
                AeronTensorPool.Agents.Discovery.update_entry_from_announce!(
                    state,
                    announce_a.dec,
                    config.driver_instance_id,
                    config.driver_control_channel,
                    config.driver_control_stream_id,
                )

                announce_b = build_shm_pool_announce(
                    stream_id = UInt32(6101),
                    producer_id = UInt32(2),
                    epoch = UInt64(1),
                    layout_version = UInt32(1),
                    nslots = UInt32(8),
                    header_uri = "shm:file?path=/dev/shm/tp_header_b",
                    payload_entries = NamedTuple[],
                )
                AeronTensorPool.Agents.Discovery.update_entry_from_announce!(
                    state,
                    announce_b.dec,
                    config.driver_instance_id,
                    config.driver_control_channel,
                    config.driver_control_stream_id,
                )
                @test length(state.entries) == 2

                client_state = init_discovery_client(
                    client,
                    request_channel,
                    request_stream_id,
                    response_channel,
                    response_stream_id,
                    UInt32(71),
                )
                entries = Vector{DiscoveryEntry}()
                request_id = discover_streams!(client_state, entries)
                @test request_id != 0

                slot = nothing
                ok = wait_for() do
                    AeronTensorPool.Agents.Discovery.discovery_do_work!(state, request_asm, announce_asm)
                    slot = poll_discovery_response!(client_state, request_id)
                    slot !== nothing
                end
                @test ok
                @test slot.status == DiscoveryStatus.OK
                @test slot.count == 1
                @test length(slot.out_entries) == 1
            finally
                AeronTensorPool.Agents.Discovery.close_discovery_state!(state)
            end
        end
    end
end

@testset "Discovery response error_message length cap" begin
    with_embedded_driver() do driver
        with_client(driver = driver) do client
            response_channel = "aeron:ipc"
            response_stream_id = UInt32(6201)
            request_channel = "aeron:ipc"
            request_stream_id = Int32(6200)
            announce_channel = "aeron:ipc"
            announce_stream_id = Int32(6202)
            metadata_channel = "aeron:ipc"
            metadata_stream_id = Int32(6203)

            config = DiscoveryConfig(
                request_channel,
                request_stream_id,
                announce_channel,
                announce_stream_id,
                metadata_channel,
                metadata_stream_id,
                "driver-error",
                "aeron:ipc",
                response_stream_id,
                UInt32(10),
                UInt64(1_000_000_000),
                UInt32(65536),
                AeronTensorPool.DISCOVERY_MAX_TAGS_PER_ENTRY_DEFAULT,
                AeronTensorPool.DISCOVERY_MAX_POOLS_PER_ENTRY_DEFAULT,
            )
            state = AeronTensorPool.Agents.Discovery.init_discovery_provider(config; client = client)
            try
                response_sub = Aeron.add_subscription(client, response_channel, Int32(response_stream_id))
                error_len = Ref(0)
                got = Ref(false)
                assembler = Aeron.FragmentAssembler(Aeron.FragmentHandler(nothing) do _, buffer, _
                    header = DiscoveryMessageHeader.Decoder(buffer, 0)
                    if DiscoveryMessageHeader.templateId(header) ==
                       AeronTensorPool.TEMPLATE_DISCOVERY_RESPONSE
                        resp = DiscoveryResponse.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
                        DiscoveryResponse.wrap!(resp, buffer, 0; header = header)
                        DiscoveryResponse.results(resp)
                        err_view = DiscoveryResponse.errorMessage(resp, StringView)
                        error_len[] = length(err_view)
                        got[] = true
                    end
                    nothing
                end)

                long_msg = repeat("x", AeronTensorPool.DRIVER_ERROR_MAX_BYTES + 32)
                sent = AeronTensorPool.Agents.Discovery.emit_discovery_response!(
                    state,
                    response_channel,
                    response_stream_id,
                    UInt64(1),
                    DiscoveryStatus.ERROR,
                    state.matching_entries,
                    0,
                    long_msg,
                )
                @test sent
                ok = wait_for() do
                    Aeron.poll(response_sub, assembler, 10)
                    got[]
                end
                @test ok
                @test error_len[] == AeronTensorPool.DRIVER_ERROR_MAX_BYTES
                close(response_sub)
            finally
                AeronTensorPool.Agents.Discovery.close_discovery_state!(state)
            end
        end
    end
end

@testset "Discovery client handles error responses on max_results" begin
    with_driver_and_client() do driver, client
        sub = Aeron.add_subscription(client, "aeron:ipc", Int32(6300))
        poller = AeronTensorPool.DiscoveryClient.DiscoveryResponsePoller(sub)

        out_entries = AeronTensorPool.DiscoveryClient.DiscoveryEntry[]
        slot = AeronTensorPool.DiscoveryClient.DiscoveryResponseSlot(out_entries)
        slot.request_id = UInt64(9)
        poller.slots[slot.request_id] = slot

        buf = Vector{UInt8}(undef, 512)
        unsafe_buf = UnsafeArrays.UnsafeArray{UInt8, 1}(pointer(buf), (length(buf),))
        enc = DiscoveryResponse.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1})
        DiscoveryResponse.wrap_and_apply_header!(enc, unsafe_buf, 0)
        DiscoveryResponse.requestId!(enc, slot.request_id)
        DiscoveryResponse.status!(enc, DiscoveryStatus.ERROR)
        DiscoveryResponse.results!(enc, 0)
        DiscoveryResponse.errorMessage!(enc, "max_results exceeded")

        GC.@preserve buf begin
            AeronTensorPool.DiscoveryClient.handle_discovery_response!(poller, unsafe_buf)
        end

        @test slot.ready == true
        @test slot.status == DiscoveryStatus.ERROR
        @test slot.count == 0
        @test isempty(slot.out_entries)
        @test String(view(slot.error_message)) == "max_results exceeded"
    end
end
