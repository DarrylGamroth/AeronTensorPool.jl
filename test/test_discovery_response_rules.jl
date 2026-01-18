using Test

@testset "Discovery response request_id and status rules" begin
    with_driver_and_client() do driver, client
        sub = Aeron.add_subscription(client.aeron_client, "aeron:ipc", Int32(9120))
        poller = AeronTensorPool.DiscoveryClient.DiscoveryResponsePoller(sub)

        out_entries = AeronTensorPool.DiscoveryClient.DiscoveryEntry[]
        slot = AeronTensorPool.DiscoveryClient.DiscoveryResponseSlot(out_entries)
        slot.request_id = UInt64(1)
        poller.slots[slot.request_id] = slot

        function build_response(request_id::UInt64; status::DiscoveryStatus.SbeEnum, results_count::Int)
            buf = Vector{UInt8}(undef, 2048)
            unsafe_buf = UnsafeArrays.UnsafeArray{UInt8, 1}(pointer(buf), (length(buf),))
            enc = DiscoveryResponse.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1})
            DiscoveryResponse.wrap_and_apply_header!(enc, unsafe_buf, 0)
            DiscoveryResponse.requestId!(enc, request_id)
            DiscoveryResponse.status!(enc, status)
            results_group = DiscoveryResponse.results!(enc, results_count)
            for _ in 1:results_count
                result = DiscoveryResponse.Results.next!(results_group)
                DiscoveryResponse.Results.streamId!(result, UInt32(1))
                DiscoveryResponse.Results.producerId!(result, UInt32(2))
                DiscoveryResponse.Results.epoch!(result, UInt64(1))
                DiscoveryResponse.Results.layoutVersion!(result, UInt32(1))
                DiscoveryResponse.Results.headerNslots!(result, UInt32(8))
                DiscoveryResponse.Results.headerSlotBytes!(result, UInt16(HEADER_SLOT_BYTES))
                DiscoveryResponse.Results.maxDims!(result, UInt8(MAX_DIMS))
                DiscoveryResponse.Results.dataSourceId!(result, UInt32(1))
                DiscoveryResponse.Results.driverControlStreamId!(result, UInt32(1001))
                DiscoveryResponse.Results.payloadPools!(result, 0)
                DiscoveryResponse.Results.tags!(result, 0)
                DiscoveryResponse.Results.headerRegionUri!(result, "")
                DiscoveryResponse.Results.dataSourceName!(result, "")
                DiscoveryResponse.Results.driverInstanceId!(result, "")
                DiscoveryResponse.Results.driverControlChannel!(result, "")
            end
            DiscoveryResponse.errorMessage!(enc, "")
            return buf, unsafe_buf
        end

        buf, unsafe_buf = build_response(UInt64(2); status = DiscoveryStatus.OK, results_count = 0)
        GC.@preserve buf begin
            AeronTensorPool.DiscoveryClient.handle_discovery_response!(poller, unsafe_buf)
        end
        @test slot.ready == false

        buf, unsafe_buf = build_response(UInt64(1); status = DiscoveryStatus.ERROR, results_count = 1)
        GC.@preserve buf begin
            AeronTensorPool.DiscoveryClient.handle_discovery_response!(poller, unsafe_buf)
        end
        @test slot.ready == true
        @test slot.status == DiscoveryStatus.ERROR
        @test slot.count == 0
        @test isempty(slot.out_entries)
    end
end
