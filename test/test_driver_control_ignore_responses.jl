using Logging
using Test
using UnsafeArrays

@testset "Driver control ignores response templates" begin
    with_driver_and_client() do media_driver, client
        base_dir = mktempdir()

        endpoints = DriverEndpoints(
            "driver-test",
            Aeron.MediaDriver.aeron_dir(media_driver),
            "aeron:ipc",
            1000,
            "aeron:ipc",
            1001,
            "aeron:ipc",
            1200,
        )
        shm = DriverShmConfig(base_dir, "default", false, UInt32(4096), "660", [base_dir])
        policies = DriverPolicyConfig(false, "raw", UInt32(100), UInt32(10_000), UInt32(3), false, false, false, false, UInt32(2000), "")
        profile = DriverProfileConfig(
            "raw",
            UInt32(8),
            UInt16(256),
            UInt8(8),
            [DriverPoolConfig(UInt16(1), UInt32(1024))],
        )
        streams = Dict("cam1" => DriverStreamConfig("cam1", UInt32(1001), "raw"))
        cfg = DriverConfig(
            endpoints,
            shm,
            policies,
            Dict("raw" => profile),
            streams,
        )

        old_log = get(ENV, "TP_LOG", nothing)
        old_level = get(ENV, "TP_LOG_LEVEL", nothing)
        ENV["TP_LOG"] = "1"
        ENV["TP_LOG_LEVEL"] = string(AeronTensorPool.Core.TPLog.LEVEL_DEBUG)

        logger = Test.TestLogger(min_level = Logging.Debug)
        AeronTensorPool.Core.TPLog.set_backend!(logger)
        AeronTensorPool.Core.TPLog.update_log_settings!()

        driver_state = init_driver(cfg; client = client)
        pub = Aeron.add_publication(client, "aeron:ipc", 1000)
        claim = Aeron.BufferClaim()
        msg_len = AeronTensorPool.DRIVER_MESSAGE_HEADER_LEN +
            Int(ShmAttachResponse.sbe_block_length(ShmAttachResponse.Decoder))
        sent = with_claimed_buffer!(pub, claim, msg_len) do buf
            enc = ShmAttachResponse.Encoder(UnsafeArray{UInt8, 1})
            ShmAttachResponse.wrap_and_apply_header!(enc, buf, 0)
            ShmAttachResponse.correlationId!(enc, Int64(77))
            ShmAttachResponse.code!(enc, DriverResponseCode.OK)
            ShmAttachResponse.leaseId!(enc, UInt64(1))
            ShmAttachResponse.leaseExpiryTimestampNs!(enc, UInt64(10))
        end
        @test sent == true

        template_attach_response = ShmAttachResponse.sbe_template_id(ShmAttachResponse.Decoder)
        ok = wait_for() do
            driver_do_work!(driver_state)
            any(
                rec -> rec.message == "driver control message" &&
                    get(rec.kwargs, :template_id, nothing) == template_attach_response,
                logger.logs,
            )
        end
        @test ok == true

        warn_hits = filter(
            rec -> rec.level >= Logging.Warn &&
                occursin("block length too small", string(rec.message)),
            logger.logs,
        )
        @test isempty(warn_hits)

        close_driver_state!(driver_state)

        if old_log === nothing
            delete!(ENV, "TP_LOG")
        else
            ENV["TP_LOG"] = old_log
        end
        if old_level === nothing
            delete!(ENV, "TP_LOG_LEVEL")
        else
            ENV["TP_LOG_LEVEL"] = old_level
        end
        AeronTensorPool.Core.TPLog.update_log_settings!()
        AeronTensorPool.Core.TPLog.set_backend!(ConsoleLogger(stderr))
    end
end
