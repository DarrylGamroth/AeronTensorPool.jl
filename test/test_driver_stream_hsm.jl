using Test

@testset "Driver stream HSM" begin
    metrics = AeronTensorPool.DriverMetrics(0, 0, 0, 0, 0, 0, 0, 0)
    stream = AeronTensorPool.StreamLifecycle()

    @test AeronTensorPool.Hsm.current(stream) == :Init
    AeronTensorPool.Hsm.dispatch!(stream, :StreamProvisioned, metrics)
    @test AeronTensorPool.Hsm.current(stream) == :Active
    AeronTensorPool.Hsm.dispatch!(stream, :ProducerAttached, metrics)
    AeronTensorPool.Hsm.dispatch!(stream, :ConsumerAttached, metrics)
    @test AeronTensorPool.Hsm.current(stream) == :Active

    AeronTensorPool.Hsm.dispatch!(stream, :DriverDraining, metrics)
    @test AeronTensorPool.Hsm.current(stream) == :Draining
    AeronTensorPool.Hsm.dispatch!(stream, :StreamIdle, metrics)
    @test AeronTensorPool.Hsm.current(stream) == :Closed

    stream2 = AeronTensorPool.StreamLifecycle()
    AeronTensorPool.Hsm.dispatch!(stream2, :StreamProvisioned, metrics)
    AeronTensorPool.Hsm.dispatch!(stream2, :UnknownEvent, metrics)
    @test AeronTensorPool.Hsm.current(stream2) == :Active
    @test metrics.stream_hsm_unhandled == 1
end
