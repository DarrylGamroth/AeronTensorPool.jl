@testset "Allocation checks: driver response poller" begin
    with_driver_and_client() do media_driver, client
        sub = Aeron.add_subscription(client, "aeron:ipc", Int32(15010))
        poller = DriverResponsePoller(sub)

        buf = Vector{UInt8}(undef, 4096)
        attach_enc = ShmAttachResponse.Encoder(Vector{UInt8})
        detach_enc = ShmDetachResponse.Encoder(Vector{UInt8})
        revoke_enc = ShmLeaseRevoked.Encoder(Vector{UInt8})
        shutdown_enc = ShmDriverShutdown.Encoder(Vector{UInt8})

        function encode_attach!(header_uri::String, pool_uri::String)
            ShmAttachResponse.wrap_and_apply_header!(attach_enc, buf, 0)
            ShmAttachResponse.correlationId!(attach_enc, Int64(1))
            ShmAttachResponse.code!(attach_enc, DriverResponseCode.OK)
            ShmAttachResponse.leaseId!(attach_enc, UInt64(10))
            ShmAttachResponse.leaseExpiryTimestampNs!(attach_enc, UInt64(123))
            ShmAttachResponse.streamId!(attach_enc, UInt32(1))
            ShmAttachResponse.epoch!(attach_enc, UInt64(1))
            ShmAttachResponse.layoutVersion!(attach_enc, UInt32(1))
            ShmAttachResponse.headerNslots!(attach_enc, UInt32(8))
            ShmAttachResponse.headerSlotBytes!(attach_enc, UInt16(HEADER_SLOT_BYTES))
            ShmAttachResponse.maxDims!(attach_enc, UInt8(MAX_DIMS))
            ShmAttachResponse.headerRegionUri!(attach_enc, header_uri)
            pools = ShmAttachResponse.payloadPools!(attach_enc, 1)
            entry = ShmAttachResponse.PayloadPools.next!(pools)
            ShmAttachResponse.PayloadPools.poolId!(entry, UInt16(1))
            ShmAttachResponse.PayloadPools.poolNslots!(entry, UInt32(8))
            ShmAttachResponse.PayloadPools.strideBytes!(entry, UInt32(4096))
            ShmAttachResponse.PayloadPools.regionUri!(entry, pool_uri)
            ShmAttachResponse.errorMessage!(attach_enc, "")
            return nothing
        end

        function encode_detach!()
            ShmDetachResponse.wrap_and_apply_header!(detach_enc, buf, 0)
            ShmDetachResponse.correlationId!(detach_enc, Int64(2))
            ShmDetachResponse.code!(detach_enc, DriverResponseCode.OK)
            ShmDetachResponse.errorMessage!(detach_enc, "")
            return nothing
        end

        function encode_revoke!()
            ShmLeaseRevoked.wrap_and_apply_header!(revoke_enc, buf, 0)
            ShmLeaseRevoked.timestampNs!(revoke_enc, UInt64(10))
            ShmLeaseRevoked.leaseId!(revoke_enc, UInt64(20))
            ShmLeaseRevoked.streamId!(revoke_enc, UInt32(1))
            ShmLeaseRevoked.clientId!(revoke_enc, UInt32(2))
            ShmLeaseRevoked.role!(revoke_enc, DriverRole.CONSUMER)
            ShmLeaseRevoked.reason!(revoke_enc, DriverLeaseRevokeReason.EXPIRED)
            ShmLeaseRevoked.errorMessage!(revoke_enc, "")
            return nothing
        end

        function encode_shutdown!()
            ShmDriverShutdown.wrap_and_apply_header!(shutdown_enc, buf, 0)
            ShmDriverShutdown.timestampNs!(shutdown_enc, UInt64(10))
            ShmDriverShutdown.reason!(shutdown_enc, DriverShutdownReason.NORMAL)
            ShmDriverShutdown.errorMessage!(shutdown_enc, "")
            return nothing
        end

        unsafe_buf = UnsafeArrays.UnsafeArray{UInt8, 1}(pointer(buf), (length(buf),))

        encode_attach!("shm:file?path=/tmp/header", "shm:file?path=/tmp/pool")
        GC.@preserve buf begin
            AeronTensorPool.handle_driver_response!(poller, unsafe_buf)
        end
        encode_attach!("shm:file?path=/tmp/header", "shm:file?path=/tmp/pool")
        GC.@preserve buf begin
            @test @allocated(AeronTensorPool.handle_driver_response!(poller, unsafe_buf)) == 0
        end

        encode_detach!()
        GC.@preserve buf begin
            @test @allocated(AeronTensorPool.handle_driver_response!(poller, unsafe_buf)) == 0
        end

        encode_revoke!()
        GC.@preserve buf begin
            @test @allocated(AeronTensorPool.handle_driver_response!(poller, unsafe_buf)) == 0
        end

        encode_shutdown!()
        GC.@preserve buf begin
            @test @allocated(AeronTensorPool.handle_driver_response!(poller, unsafe_buf)) == 0
        end

        close(sub)
    end
end
