@testset "Driver client handles duplicate revoke idempotently" begin
    with_driver_and_client() do driver, client
        driver_client = init_driver_client(client.aeron_client,
            "aeron:ipc",
            Int32(14060),
            UInt32(88),
            DriverRole.CONSUMER,
        )
        try
            driver_client.lease_id = UInt64(22)
            revoke = LeaseRevoked()
            revoke.lease_id = UInt64(22)
            revoke.stream_id = UInt32(2000)
            revoke.role = DriverRole.CONSUMER
            revoke.reason = DriverLeaseRevokeReason.EXPIRED
            driver_client.poller.last_revoke = revoke

            now_ns = UInt64(time_ns())
            driver_client_do_work!(driver_client, now_ns)
            @test driver_client.revoked
            @test driver_client.lease_id == UInt64(0)

            driver_client_do_work!(driver_client, now_ns + 1)
            @test driver_client.revoked
            @test driver_client.lease_id == UInt64(0)
        finally
            close(driver_client.pub)
            close(driver_client.sub)
        end
    end
end
