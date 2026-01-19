using Random
using Test

@testset "Driver client correlation rules" begin
    with_driver_and_client() do _, client
        Random.seed!(1234)
        expected_low = rand(UInt32)
        expected_low == 0 && (expected_low = UInt32(1))

        Random.seed!(1234)
        driver_client = AeronTensorPool.init_driver_client(
            client.aeron_client,
            "aeron:ipc",
            Int32(16000),
            UInt32(7),
            AeronTensorPool.DriverRole.CONSUMER,
        )
        first_id = AeronTensorPool.next_correlation_id!(driver_client)
        second_id = AeronTensorPool.next_correlation_id!(driver_client)
        low = UInt32(UInt64(first_id) & 0xffff_ffff)
        @test low == expected_low
        @test first_id != second_id

        poller = AeronTensorPool.DriverResponsePoller(
            Aeron.add_subscription(client.aeron_client, "aeron:ipc", Int32(16001)),
        )
        buf = Vector{UInt8}(undef, 512)
        unsafe_buf = UnsafeArrays.UnsafeArray{UInt8, 1}(pointer(buf), (length(buf),))
        enc = AeronTensorPool.ShmAttachResponse.Encoder(Vector{UInt8})

        function write_attach!(
            code::AeronTensorPool.DriverResponseCode.SbeEnum,
            correlation_id::Int64,
            error_message::AbstractString = "",
        )
            AeronTensorPool.ShmAttachResponse.wrap_and_apply_header!(enc, buf, 0)
            AeronTensorPool.ShmAttachResponse.correlationId!(enc, correlation_id)
            AeronTensorPool.ShmAttachResponse.code!(enc, code)
            AeronTensorPool.ShmAttachResponse.leaseId!(enc, UInt64(1))
            AeronTensorPool.ShmAttachResponse.leaseExpiryTimestampNs!(enc, UInt64(2))
            AeronTensorPool.ShmAttachResponse.streamId!(enc, UInt32(10000))
            AeronTensorPool.ShmAttachResponse.epoch!(enc, UInt64(1))
            AeronTensorPool.ShmAttachResponse.layoutVersion!(enc, UInt32(1))
            AeronTensorPool.ShmAttachResponse.headerNslots!(enc, UInt32(8))
            AeronTensorPool.ShmAttachResponse.headerSlotBytes!(
                enc,
                UInt16(AeronTensorPool.HEADER_SLOT_BYTES),
            )
            AeronTensorPool.ShmAttachResponse.nodeId!(enc, UInt32(1))
            AeronTensorPool.ShmAttachResponse.payloadPools!(enc, 0)
            AeronTensorPool.ShmAttachResponse.headerRegionUri!(enc, "")
            AeronTensorPool.ShmAttachResponse.errorMessage!(enc, error_message)
            return nothing
        end

        corr = Int64(101)
        write_attach!(AeronTensorPool.DriverResponseCode.OK, corr)
        GC.@preserve buf begin
            @test AeronTensorPool.handle_driver_response!(poller, unsafe_buf) == true
        end
        @test poller.attach_by_correlation[corr].code == AeronTensorPool.DriverResponseCode.OK

        write_attach!(
            AeronTensorPool.DriverResponseCode.REJECTED,
            corr,
            "client_id already attached",
        )
        GC.@preserve buf begin
            @test AeronTensorPool.handle_driver_response!(poller, unsafe_buf) == true
        end
        @test poller.attach_by_correlation[corr].code == AeronTensorPool.DriverResponseCode.OK
    end
end
