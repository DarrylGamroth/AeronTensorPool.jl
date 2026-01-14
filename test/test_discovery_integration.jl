using Test
using Aeron
using AeronTensorPool
using SBE
using UnsafeArrays

function offer_shm_pool_announce!(
    pub::Aeron.Publication,
    stream_id::UInt32,
    producer_id::UInt32,
    header_uri::AbstractString,
    pool_uri::AbstractString,
)
    announce = build_shm_pool_announce(
        stream_id = stream_id,
        producer_id = producer_id,
        epoch = UInt64(1),
        layout_version = UInt32(1),
        nslots = UInt32(8),
        stride_bytes = UInt32(1024),
        header_uri = header_uri,
        pool_uri = pool_uri,
    )
    Aeron.offer(pub, view(announce.buf, 1:announce.len))
    return nothing
end

function offer_data_source_announce!(
    pub::Aeron.Publication,
    stream_id::UInt32,
    producer_id::UInt32,
    name::AbstractString,
)
    buf = Vector{UInt8}(undef, 512)
    enc = AeronTensorPool.DataSourceAnnounce.Encoder(Vector{UInt8})
    AeronTensorPool.DataSourceAnnounce.wrap_and_apply_header!(enc, buf, 0)
    AeronTensorPool.DataSourceAnnounce.streamId!(enc, stream_id)
    AeronTensorPool.DataSourceAnnounce.producerId!(enc, producer_id)
    AeronTensorPool.DataSourceAnnounce.epoch!(enc, UInt64(1))
    AeronTensorPool.DataSourceAnnounce.metaVersion!(enc, UInt32(1))
    AeronTensorPool.DataSourceAnnounce.name!(enc, name)
    AeronTensorPool.DataSourceAnnounce.summary!(enc, "")
    Aeron.offer(pub, view(buf, 1:sbe_message_length(enc)))
    return nothing
end

function offer_discovery_request!(
    pub::Aeron.Publication,
    request_id::UInt64;
    response_channel::AbstractString,
    response_stream_id::UInt32,
)
    buf = Vector{UInt8}(undef, 512)
    enc = AeronTensorPool.DiscoveryRequest.Encoder(Vector{UInt8})
    AeronTensorPool.DiscoveryRequest.wrap_and_apply_header!(enc, buf, 0)
    AeronTensorPool.DiscoveryRequest.requestId!(enc, request_id)
    AeronTensorPool.DiscoveryRequest.clientId!(enc, UInt32(1))
    AeronTensorPool.DiscoveryRequest.responseStreamId!(enc, response_stream_id)
    AeronTensorPool.DiscoveryRequest.streamId!(
        enc,
        AeronTensorPool.DiscoveryRequest.streamId_null_value(AeronTensorPool.DiscoveryRequest.Decoder),
    )
    AeronTensorPool.DiscoveryRequest.producerId!(
        enc,
        AeronTensorPool.DiscoveryRequest.producerId_null_value(AeronTensorPool.DiscoveryRequest.Decoder),
    )
    AeronTensorPool.DiscoveryRequest.dataSourceId!(
        enc,
        AeronTensorPool.DiscoveryRequest.dataSourceId_null_value(AeronTensorPool.DiscoveryRequest.Decoder),
    )
    AeronTensorPool.DiscoveryRequest.tags!(enc, 0)
    AeronTensorPool.DiscoveryRequest.responseChannel!(enc, response_channel)
    AeronTensorPool.DiscoveryRequest.dataSourceName!(enc, "")
    msg_len = AeronTensorPool.DISCOVERY_MESSAGE_HEADER_LEN + sbe_encoded_length(enc)
    Aeron.offer(pub, view(buf, 1:msg_len))
    return nothing
end

@testset "Discovery integration" begin
    with_embedded_driver() do driver
        with_client(driver = driver) do client
            request_channel = "aeron:ipc"
            request_stream_id = Int32(5100)
            response_channel = "aeron:ipc"
            response_stream_id = UInt32(5101)
            announce_channel = "aeron:ipc"
            announce_stream_id = Int32(5102)
            metadata_channel = "aeron:ipc"
            metadata_stream_id = Int32(5103)

            config = DiscoveryConfig(
                request_channel,
                request_stream_id,
                announce_channel,
                announce_stream_id,
                metadata_channel,
                metadata_stream_id,
                "driver-1",
                "aeron:ipc",
                UInt32(5104),
                UInt32(100),
                UInt64(1_000_000_000),
                UInt32(65536),
                AeronTensorPool.DISCOVERY_MAX_TAGS_PER_ENTRY_DEFAULT,
                AeronTensorPool.DISCOVERY_MAX_POOLS_PER_ENTRY_DEFAULT,
            )
            state = AeronTensorPool.Agents.Discovery.init_discovery_provider(config; client = client)
            request_asm = AeronTensorPool.Agents.Discovery.make_request_assembler(state)
            announce_asm = AeronTensorPool.Agents.Discovery.make_announce_assembler(state)
            metadata_asm = AeronTensorPool.Agents.Discovery.make_metadata_assembler(state)

            pub_announce = Aeron.add_publication(client, announce_channel, announce_stream_id)
            pub_metadata = Aeron.add_publication(client, metadata_channel, metadata_stream_id)
            offer_shm_pool_announce!(
                pub_announce,
                UInt32(42),
                UInt32(7),
                "shm:file?path=/tmp/tp_header",
                "shm:file?path=/tmp/tp_pool",
            )
            offer_data_source_announce!(pub_metadata, UInt32(42), UInt32(7), "camera-1")

            ok = wait_for() do
                AeronTensorPool.Agents.Discovery.discovery_do_work!(
                    state,
                    request_asm,
                    announce_asm;
                    metadata_assembler = metadata_asm,
                )
                length(state.entries) == 1
            end
            @test ok

            client_state = init_discovery_client(
                client,
                request_channel,
                request_stream_id,
                response_channel,
                response_stream_id,
                UInt32(77),
            )
            entries = Vector{DiscoveryEntry}()
            request_id = discover_streams!(client_state, entries; data_source_name = "camera-1")
            @test request_id != 0
            slot = nothing
            ok = wait_for() do
                AeronTensorPool.Agents.Discovery.discovery_do_work!(
                    state,
                    request_asm,
                    announce_asm;
                    metadata_assembler = metadata_asm,
                )
                slot = poll_discovery_response!(client_state, request_id)
                slot !== nothing
            end
            @test ok
            @test slot.status == DiscoveryStatus.OK
            @test slot.count == 1
            @test slot.out_entries[1].stream_id == UInt32(42)
            @test String(view(slot.out_entries[1].data_source_name)) == "camera-1"

            close(pub_announce)
            close(pub_metadata)
        end
    end
end

@testset "Discovery request validation" begin
    with_embedded_driver() do driver
        with_client(driver = driver) do client
            request_channel = "aeron:ipc"
            request_stream_id = Int32(5200)
            announce_channel = "aeron:ipc"
            announce_stream_id = Int32(5201)
            metadata_channel = "aeron:ipc"
            metadata_stream_id = Int32(5202)

            config = DiscoveryConfig(
                request_channel,
                request_stream_id,
                announce_channel,
                announce_stream_id,
                metadata_channel,
                metadata_stream_id,
                "driver-2",
                "aeron:ipc",
                UInt32(5203),
                UInt32(10),
                UInt64(1_000_000_000),
                UInt32(65536),
                AeronTensorPool.DISCOVERY_MAX_TAGS_PER_ENTRY_DEFAULT,
                AeronTensorPool.DISCOVERY_MAX_POOLS_PER_ENTRY_DEFAULT,
            )
            state = AeronTensorPool.Agents.Discovery.init_discovery_provider(config; client = client)
            request_asm = AeronTensorPool.Agents.Discovery.make_request_assembler(state)
            announce_asm = AeronTensorPool.Agents.Discovery.make_announce_assembler(state)
            metadata_asm = AeronTensorPool.Agents.Discovery.make_metadata_assembler(state)

            pub_req = Aeron.add_publication(client, request_channel, request_stream_id)
            offer_discovery_request!(
                pub_req,
                UInt64(1);
                response_channel = "",
                response_stream_id = UInt32(5101),
            )
            AeronTensorPool.Agents.Discovery.discovery_do_work!(
                state,
                request_asm,
                announce_asm;
                metadata_assembler = metadata_asm,
            )
            @test isempty(state.runtime.pubs)

            response_channel = "aeron:ipc"
            response_sub = Aeron.add_subscription(client, response_channel, 0)
            got = Ref(false)
            status = Ref(DiscoveryStatus.OK)
            assembler = Aeron.FragmentAssembler(Aeron.FragmentHandler(nothing) do _, buffer, _
                header = DiscoveryMessageHeader.Decoder(buffer, 0)
                if AeronTensorPool.DiscoveryMessageHeader.templateId(header) ==
                   AeronTensorPool.TEMPLATE_DISCOVERY_RESPONSE
                    resp = AeronTensorPool.DiscoveryResponse.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
                    AeronTensorPool.DiscoveryResponse.wrap!(resp, buffer, 0; header = header)
                    status[] = AeronTensorPool.DiscoveryResponse.status(resp)
                    got[] = true
                end
                nothing
            end)

            offer_discovery_request!(
                pub_req,
                UInt64(2);
                response_channel = response_channel,
                response_stream_id = UInt32(0),
            )
            ok = wait_for() do
                AeronTensorPool.Agents.Discovery.discovery_do_work!(
                    state,
                    request_asm,
                    announce_asm;
                    metadata_assembler = metadata_asm,
                )
                Aeron.poll(response_sub, assembler, 10)
                got[]
            end
            @test ok
            @test status[] == DiscoveryStatus.ERROR

            close(response_sub)
            close(pub_req)
        end
    end
end
