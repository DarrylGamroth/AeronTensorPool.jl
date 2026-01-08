@testset "QoS monitor allocations" begin
    with_driver_and_client() do driver, client
        monitor = QosMonitor("aeron:ipc", Int32(1200); client = client)
        try
            poll!(monitor)
            @test @allocated(poll!(monitor)) == 0
        finally
            close(monitor)
        end
    end
end
