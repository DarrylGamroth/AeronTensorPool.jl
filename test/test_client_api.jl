using Test

@testset "TensorPool client API" begin
    with_driver_and_client() do media_driver, client
        endpoints = DriverEndpoints(
            "client-api-test",
            Aeron.MediaDriver.aeron_dir(media_driver),
            "aeron:ipc",
            1000,
            "aeron:ipc",
            1001,
            "aeron:ipc",
            1200,
        )
        ctx = TensorPoolContext(endpoints)
        tp_client = connect(ctx; aeron_client = client)
        @test isopen(client)
        close(tp_client)
        @test isopen(client)
    end
end

@testset "TensorPool invoker do_work" begin
    with_embedded_driver() do media_driver
        endpoints = DriverEndpoints(
            "client-api-invoker",
            Aeron.MediaDriver.aeron_dir(media_driver),
            "aeron:ipc",
            1000,
            "aeron:ipc",
            1001,
            "aeron:ipc",
            1200,
        )
        Aeron.Context() do aeron_ctx
            Aeron.aeron_dir!(aeron_ctx, Aeron.MediaDriver.aeron_dir(media_driver))
            ctx = TensorPoolContext(endpoints; use_invoker = true)
            tp_client = connect(ctx; aeron_context = aeron_ctx)
            work = do_work(tp_client)
            @test work isa Integer
            close(tp_client)
        end
    end
end
