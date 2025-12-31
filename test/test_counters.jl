@testset "Counters" begin
    with_embedded_driver() do driver
        Aeron.Context() do context
            Aeron.aeron_dir!(context, Aeron.MediaDriver.aeron_dir(driver))
            Aeron.Client(context) do client
                base = Counters(client, 1, "TestAgent")
                @test base.total_duty_cycles isa Aeron.Counter
                @test base.total_work_done isa Aeron.Counter

                Aeron.increment!(base.total_duty_cycles)
                Aeron.add!(base.total_work_done, 5)
                @test base.total_duty_cycles[] >= 1
                @test base.total_work_done[] >= 5

                prod = ProducerCounters(client, 2, "Producer")
                @test prod.frames_published isa Aeron.Counter
                @test prod.announces isa Aeron.Counter
                @test prod.qos_published isa Aeron.Counter

                cons = ConsumerCounters(client, 3, "Consumer")
                @test cons.drops_gap isa Aeron.Counter
                @test cons.drops_late isa Aeron.Counter
                @test cons.drops_odd isa Aeron.Counter
                @test cons.drops_changed isa Aeron.Counter
                @test cons.drops_frame_id_mismatch isa Aeron.Counter
                @test cons.drops_header_invalid isa Aeron.Counter
                @test cons.drops_payload_invalid isa Aeron.Counter
                @test cons.remaps isa Aeron.Counter
                @test cons.hello_published isa Aeron.Counter
                @test cons.qos_published isa Aeron.Counter

                sup = SupervisorCounters(client, 4, "Supervisor")
                @test sup.base.total_duty_cycles isa Aeron.Counter
                @test sup.config_published isa Aeron.Counter
                @test sup.liveness_checks isa Aeron.Counter

                close(base)
                close(prod)
                close(cons)
                close(sup)
            end
        end
    end
end
