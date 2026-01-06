using Test

@testset "Attach burst across roles" begin
    with_driver_and_client() do media_driver, client
        base_dir = mktempdir()

        endpoints = DriverEndpoints(
            "driver-test",
            Aeron.MediaDriver.aeron_dir(media_driver),
            "aeron:ipc",
            13320,
            "aeron:ipc",
            13321,
            "aeron:ipc",
            13322,
        )
        shm = DriverShmConfig(base_dir, false, UInt32(4096), "660", [base_dir])
        policies = DriverPolicies(false, "raw", UInt32(100), UInt32(100), UInt32(2), false, false, UInt32(2000), "")
        profile = DriverProfileConfig(
            "raw",
            UInt32(8),
            UInt16(256),
            UInt8(8),
            [DriverPoolConfig(UInt16(1), UInt32(4096))],
        )
        streams = Dict("cam1" => DriverStreamConfig("cam1", UInt32(57), "raw"))
        cfg = DriverConfig(endpoints, shm, policies, Dict("raw" => profile), streams)
        driver_state = init_driver(cfg; client = client)

        producer_client = init_driver_client(
            client,
            "aeron:ipc",
            Int32(13320),
            UInt32(41),
            DriverRole.PRODUCER,
        )
        consumer_client = init_driver_client(
            client,
            "aeron:ipc",
            Int32(13320),
            UInt32(42),
            DriverRole.CONSUMER,
        )

        prod_ids = [
            send_attach_request!(producer_client; stream_id = UInt32(57)),
            send_attach_request!(producer_client; stream_id = UInt32(57)),
            send_attach_request!(producer_client; stream_id = UInt32(57)),
        ]
        cons_ids = [
            send_attach_request!(consumer_client; stream_id = UInt32(57)),
            send_attach_request!(consumer_client; stream_id = UInt32(57)),
        ]
        @test all(!=(0), prod_ids)
        @test all(!=(0), cons_ids)

        prod_seen = Dict{Int64, Bool}()
        cons_seen = Dict{Int64, Bool}()

        ok = wait_for(; timeout = 5.0) do
            driver_do_work!(driver_state)
            driver_client_do_work!(producer_client, UInt64(time_ns()))
            driver_client_do_work!(consumer_client, UInt64(time_ns()))

            for cid in prod_ids
                get!(prod_seen, cid, false) || begin
                    attach = AeronTensorPool.Control.poll_attach!(producer_client, cid, UInt64(time_ns()))
                    attach !== nothing && (prod_seen[cid] = true)
                end
            end
            for cid in cons_ids
                get!(cons_seen, cid, false) || begin
                    attach = AeronTensorPool.Control.poll_attach!(consumer_client, cid, UInt64(time_ns()))
                    attach !== nothing && (cons_seen[cid] = true)
                end
            end

            all(values(prod_seen)) && all(values(cons_seen))
        end
        @test ok

        close_driver_state!(driver_state)
    end
end
