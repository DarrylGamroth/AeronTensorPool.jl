@testset "Counters" begin
    with_embedded_driver() do driver
        Aeron.Context() do context
            Aeron.aeron_dir!(context, Aeron.MediaDriver.aeron_dir(driver))
            Aeron.Client(context) do client
                counters = Counters(client, 1, "TestAgent")
                @test counters.total_duty_cycles isa Aeron.Counter
                @test counters.total_work_done isa Aeron.Counter

                Aeron.increment!(counters.total_duty_cycles)
                Aeron.add!(counters.total_work_done, 5)
                @test counters.total_duty_cycles[] >= 1
                @test counters.total_work_done[] >= 5

                close(counters)
            end
        end
    end
end
