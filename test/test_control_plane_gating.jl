using Test

@testset "Control plane gating without subscribers" begin
    with_embedded_driver() do media_driver
        with_client(; driver = media_driver) do client
            control_channel = "aeron:ipc"
            control_stream = Int32(13330)
            driver_client = init_driver_client(
                client,
                control_channel,
                control_stream,
                UInt32(50),
                DriverRole.CONSUMER,
            )

            close(driver_client.sub)
            ok = wait_for(; timeout = 1.0) do
                !Aeron.is_connected(driver_client.pub)
            end
            @test ok

            cid = send_attach_request!(driver_client; stream_id = UInt32(10000))
            @test cid == 0

            close(driver_client.pub)
        end
    end
end
