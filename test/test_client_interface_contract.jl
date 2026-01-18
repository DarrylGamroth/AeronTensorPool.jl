using Test

@testset "TensorPool client/runtime interface" begin
    with_driver_and_client() do media_driver, tp_client
        ctx = AeronTensorPool.client_context(tp_client)
        @test ctx === tp_client.context
        @test AeronTensorPool.aeron_client(tp_client) === tp_client.aeron_client
        @test AeronTensorPool.control_runtime(tp_client) === nothing
        @test AeronTensorPool.do_work(tp_client) == 0

        aeron_handle = AeronTensorPool.aeron_client(tp_client)
        close(tp_client)
        @test isopen(aeron_handle)

        runtime = AeronTensorPool.TensorPoolRuntime(ctx; aeron_client = aeron_handle, create_control = false)
        @test AeronTensorPool.client_context(runtime) === ctx
        @test AeronTensorPool.aeron_client(runtime) === aeron_handle
        @test AeronTensorPool.control_runtime(runtime) === nothing
        close(runtime)
        @test isopen(aeron_handle)

        runtime_control = AeronTensorPool.TensorPoolRuntime(ctx; aeron_client = aeron_handle, create_control = true)
        @test AeronTensorPool.control_runtime(runtime_control) !== nothing
        close(runtime_control)
        @test isopen(aeron_handle)
    end
end
