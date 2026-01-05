using Test
using Aeron
using AeronTensorPool
using SBE

function offer_shm_pool_announce!(
    pub::Aeron.Publication,
    stream_id::UInt32,
    producer_id::UInt32,
    header_uri::AbstractString,
    pool_uri::AbstractString,
)
    buf = Vector{UInt8}(undef, 1024)
    enc = ShmPoolAnnounce.Encoder(Vector{UInt8})
    ShmPoolAnnounce.wrap_and_apply_header!(enc, buf, 0)
    ShmPoolAnnounce.streamId!(enc, stream_id)
    ShmPoolAnnounce.producerId!(enc, producer_id)
    ShmPoolAnnounce.epoch!(enc, UInt64(1))
    ShmPoolAnnounce.announceTimestampNs!(enc, UInt64(time_ns()))
    ShmPoolAnnounce.layoutVersion!(enc, UInt32(1))
    ShmPoolAnnounce.headerNslots!(enc, UInt32(8))
    ShmPoolAnnounce.headerSlotBytes!(enc, UInt16(HEADER_SLOT_BYTES))
    ShmPoolAnnounce.maxDims!(enc, UInt8(MAX_DIMS))
    pools = ShmPoolAnnounce.payloadPools!(enc, 1)
    pool_entry = ShmPoolAnnounce.PayloadPools.next!(pools)
    ShmPoolAnnounce.PayloadPools.poolId!(pool_entry, UInt16(1))
    ShmPoolAnnounce.PayloadPools.poolNslots!(pool_entry, UInt32(8))
    ShmPoolAnnounce.PayloadPools.strideBytes!(pool_entry, UInt32(1024))
    ShmPoolAnnounce.PayloadPools.regionUri!(pool_entry, pool_uri)
    ShmPoolAnnounce.headerRegionUri!(enc, header_uri)
    Aeron.offer(pub, view(buf, 1:sbe_message_length(enc)))
    return nothing
end

function offer_data_source_announce!(
    pub::Aeron.Publication,
    stream_id::UInt32,
    producer_id::UInt32,
    name::AbstractString,
)
    buf = Vector{UInt8}(undef, 512)
    enc = DataSourceAnnounce.Encoder(Vector{UInt8})
    DataSourceAnnounce.wrap_and_apply_header!(enc, buf, 0)
    DataSourceAnnounce.streamId!(enc, stream_id)
    DataSourceAnnounce.producerId!(enc, producer_id)
    DataSourceAnnounce.epoch!(enc, UInt64(1))
    DataSourceAnnounce.metaVersion!(enc, UInt32(1))
    DataSourceAnnounce.name!(enc, name)
    DataSourceAnnounce.summary!(enc, "")
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
    enc = DiscoveryRequest.Encoder(Vector{UInt8})
    DiscoveryRequest.wrap_and_apply_header!(enc, buf, 0)
    DiscoveryRequest.requestId!(enc, request_id)
    DiscoveryRequest.clientId!(enc, UInt32(1))
    DiscoveryRequest.responseStreamId!(enc, response_stream_id)
    DiscoveryRequest.streamId!(enc, DiscoveryRequest.streamId_null_value(DiscoveryRequest.Decoder))
    DiscoveryRequest.producerId!(enc, DiscoveryRequest.producerId_null_value(DiscoveryRequest.Decoder))
    DiscoveryRequest.dataSourceId!(enc, DiscoveryRequest.dataSourceId_null_value(DiscoveryRequest.Decoder))
    DiscoveryRequest.tags!(enc, 0)
    DiscoveryRequest.responseChannel!(enc, response_channel)
    DiscoveryRequest.dataSourceName!(enc, "")
    msg_len = DISCOVERY_MESSAGE_HEADER_LEN + sbe_encoded_length(enc)
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
            )
            state = init_discovery_provider(config; client = client)
            request_asm = make_request_assembler(state)
            announce_asm = make_announce_assembler(state)
            metadata_asm = make_metadata_assembler(state)

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
                discovery_do_work!(
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
                discovery_do_work!(
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
            )
            state = init_discovery_provider(config; client = client)
            request_asm = make_request_assembler(state)
            announce_asm = make_announce_assembler(state)
            metadata_asm = make_metadata_assembler(state)

            pub_req = Aeron.add_publication(client, request_channel, request_stream_id)
            offer_discovery_request!(
                pub_req,
                UInt64(1);
                response_channel = "",
                response_stream_id = UInt32(5101),
            )
            discovery_do_work!(
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
                if DiscoveryMessageHeader.templateId(header) == TEMPLATE_DISCOVERY_RESPONSE
                    resp = DiscoveryResponse.Decoder(buffer)
                    DiscoveryResponse.wrap!(resp, buffer, 0; header = header)
                    status[] = DiscoveryResponse.status(resp)
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
                discovery_do_work!(
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
