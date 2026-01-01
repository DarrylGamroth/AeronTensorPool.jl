@testset "Allocation checks: driver control-plane encoders" begin
    buf = Vector{UInt8}(undef, 256)

    attach_enc = ShmAttachRequest.Encoder(Vector{UInt8})
    keepalive_enc = ShmLeaseKeepalive.Encoder(Vector{UInt8})
    detach_enc = ShmDetachRequest.Encoder(Vector{UInt8})

    function write_attach!(enc, buffer)
        ShmAttachRequest.wrap_and_apply_header!(enc, buffer, 0)
        ShmAttachRequest.correlationId!(enc, Int64(1))
        ShmAttachRequest.streamId!(enc, UInt32(2))
        ShmAttachRequest.clientId!(enc, UInt32(3))
        ShmAttachRequest.role!(enc, DriverRole.PRODUCER)
        ShmAttachRequest.expectedLayoutVersion!(enc, UInt32(1))
        ShmAttachRequest.maxDims!(enc, UInt8(8))
        ShmAttachRequest.publishMode!(enc, DriverPublishMode.REQUIRE_EXISTING)
        ShmAttachRequest.requireHugepages!(enc, DriverHugepagesPolicy.UNSPECIFIED)
        return nothing
    end

    function write_keepalive!(enc, buffer)
        ShmLeaseKeepalive.wrap_and_apply_header!(enc, buffer, 0)
        ShmLeaseKeepalive.leaseId!(enc, UInt64(10))
        ShmLeaseKeepalive.streamId!(enc, UInt32(2))
        ShmLeaseKeepalive.clientId!(enc, UInt32(3))
        ShmLeaseKeepalive.role!(enc, DriverRole.PRODUCER)
        ShmLeaseKeepalive.clientTimestampNs!(enc, UInt64(123))
        return nothing
    end

    function write_detach!(enc, buffer)
        ShmDetachRequest.wrap_and_apply_header!(enc, buffer, 0)
        ShmDetachRequest.correlationId!(enc, Int64(2))
        ShmDetachRequest.leaseId!(enc, UInt64(10))
        ShmDetachRequest.streamId!(enc, UInt32(2))
        ShmDetachRequest.clientId!(enc, UInt32(3))
        ShmDetachRequest.role!(enc, DriverRole.PRODUCER)
        return nothing
    end

    write_attach!(attach_enc, buf)
    write_keepalive!(keepalive_enc, buf)
    write_detach!(detach_enc, buf)

    @test @allocated(write_attach!(attach_enc, buf)) == 0
    @test @allocated(write_keepalive!(keepalive_enc, buf)) == 0
    @test @allocated(write_detach!(detach_enc, buf)) == 0
end
