@testset "QoS monitor allocations" begin
    with_driver_and_client() do driver, client
        monitor = QosMonitor("aeron:ipc", Int32(1200); client = client)
        try
            poll_qos!(monitor)
            @test @allocated(poll_qos!(monitor)) == 0
        finally
            close(monitor)
        end
    end
end
