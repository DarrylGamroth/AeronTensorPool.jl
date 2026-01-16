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
                @test prod.descriptor_backpressured isa Aeron.Counter
                @test prod.descriptor_not_connected isa Aeron.Counter
                @test prod.descriptor_admin_action isa Aeron.Counter
                @test prod.descriptor_closed isa Aeron.Counter
                @test prod.descriptor_max_position_exceeded isa Aeron.Counter
                @test prod.descriptor_errors isa Aeron.Counter

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

                driver = DriverCounters(client, 5, "Driver")
                @test driver.attach_responses isa Aeron.Counter
                @test driver.attach_response_drops isa Aeron.Counter
                @test driver.detach_responses isa Aeron.Counter
                @test driver.keepalives isa Aeron.Counter
                @test driver.lease_revoked isa Aeron.Counter
                @test driver.announces isa Aeron.Counter
                @test driver.lease_hsm_unhandled isa Aeron.Counter

                bridge = BridgeCounters(client, 6, "Bridge")
                @test bridge.frames_forwarded isa Aeron.Counter
                @test bridge.chunks_sent isa Aeron.Counter
                @test bridge.chunks_dropped isa Aeron.Counter
                @test bridge.assemblies_reset isa Aeron.Counter
                @test bridge.control_forwarded isa Aeron.Counter
                @test bridge.frames_rematerialized isa Aeron.Counter

                close(base)
                close(prod)
                close(cons)
                close(sup)
                close(driver)
                close(bridge)
            end
        end
    end
end
