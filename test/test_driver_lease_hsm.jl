using Test

@testset "Driver lease HSM" begin
    lease = AeronTensorPool.LeaseLifecycle()

    @test AeronTensorPool.Hsm.current(lease) == :Init
    AeronTensorPool.Hsm.dispatch!(lease, :AttachOk)
    @test AeronTensorPool.Hsm.current(lease) == :Active
    AeronTensorPool.Hsm.dispatch!(lease, :Keepalive)
    @test AeronTensorPool.Hsm.current(lease) == :Active
    AeronTensorPool.Hsm.dispatch!(lease, :Detach)
    @test AeronTensorPool.Hsm.current(lease) == :Detached
    AeronTensorPool.Hsm.dispatch!(lease, :Close)
    @test AeronTensorPool.Hsm.current(lease) == :Closed

    lease2 = AeronTensorPool.LeaseLifecycle()
    AeronTensorPool.Hsm.dispatch!(lease2, :AttachOk)
    AeronTensorPool.Hsm.dispatch!(lease2, :LeaseTimeout)
    @test AeronTensorPool.Hsm.current(lease2) == :Expired
    AeronTensorPool.Hsm.dispatch!(lease2, :Close)
    @test AeronTensorPool.Hsm.current(lease2) == :Closed

    lease3 = AeronTensorPool.LeaseLifecycle()
    AeronTensorPool.Hsm.dispatch!(lease3, :AttachOk)
    AeronTensorPool.Hsm.dispatch!(lease3, :Revoke)
    @test AeronTensorPool.Hsm.current(lease3) == :Revoked
    AeronTensorPool.Hsm.dispatch!(lease3, :Close)
    @test AeronTensorPool.Hsm.current(lease3) == :Closed
end
