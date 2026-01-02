using Test

@testset "Driver lease HSM" begin
    metrics = AeronTensorPool.DriverMetrics(0, 0, 0, 0, 0, 0, 0)
    lease = AeronTensorPool.LeaseLifecycle()

    @test AeronTensorPool.Hsm.current(lease) == :Init
    AeronTensorPool.Hsm.dispatch!(lease, :AttachOk, metrics)
    @test AeronTensorPool.Hsm.current(lease) == :Active
    AeronTensorPool.Hsm.dispatch!(lease, :Keepalive, metrics)
    @test AeronTensorPool.Hsm.current(lease) == :Active
    AeronTensorPool.Hsm.dispatch!(lease, :Detach, metrics)
    @test AeronTensorPool.Hsm.current(lease) == :Detached
    AeronTensorPool.Hsm.dispatch!(lease, :Close, metrics)
    @test AeronTensorPool.Hsm.current(lease) == :Closed

    lease2 = AeronTensorPool.LeaseLifecycle()
    AeronTensorPool.Hsm.dispatch!(lease2, :AttachOk, metrics)
    AeronTensorPool.Hsm.dispatch!(lease2, :LeaseTimeout, metrics)
    @test AeronTensorPool.Hsm.current(lease2) == :Expired
    AeronTensorPool.Hsm.dispatch!(lease2, :Close, metrics)
    @test AeronTensorPool.Hsm.current(lease2) == :Closed

    lease3 = AeronTensorPool.LeaseLifecycle()
    AeronTensorPool.Hsm.dispatch!(lease3, :AttachOk, metrics)
    AeronTensorPool.Hsm.dispatch!(lease3, :Revoke, metrics)
    @test AeronTensorPool.Hsm.current(lease3) == :Revoked
    AeronTensorPool.Hsm.dispatch!(lease3, :Close, metrics)
    @test AeronTensorPool.Hsm.current(lease3) == :Closed

    lease4 = AeronTensorPool.LeaseLifecycle()
    AeronTensorPool.Hsm.dispatch!(lease4, :AttachOk, metrics)
    AeronTensorPool.Hsm.dispatch!(lease4, :UnknownEvent, metrics)
    @test AeronTensorPool.Hsm.current(lease4) == :Active
    @test metrics.lease_hsm_unhandled == 1
end
