using Test

@testset "Attach backoff retries with interval" begin
    with_driver_and_client() do driver, client
        control_channel = "aeron:ipc"
        control_stream = Int32(15521)
        driver_client = init_driver_client(client.aeron_client,
            control_channel,
            control_stream,
            UInt32(90),
            DriverRole.CONSUMER,
        )

        sub = Aeron.add_subscription(client.aeron_client, control_channel, control_stream)
        count = Ref(0)
        handler = Aeron.FragmentHandler(count) do cnt, buffer, _
            header = DriverMessageHeader.Decoder(buffer, 0)
            DriverMessageHeader.templateId(header) == AeronTensorPool.TEMPLATE_SHM_ATTACH_REQUEST || return nothing
            cnt[] += 1
            nothing
        end
        assembler = Aeron.FragmentAssembler(handler)

        running = Ref(true)
        poll_task = @async begin
            while running[]
                Aeron.poll(sub, assembler, Int32(10))
                yield()
            end
        end

        cid = send_attach_request!(driver_client; stream_id = UInt32(10000))
        @test cid != 0

        ctx = TensorPoolContext(
            aeron_dir = Aeron.MediaDriver.aeron_dir(driver),
            control_channel = control_channel,
            control_stream_id = control_stream,
            use_invoker = false,
            attach_timeout_ns = UInt64(200_000_000),
            attach_retry_interval_ns = UInt64(50_000_000),
        )
        tp_client = connect(ctx; aeron_client = client.aeron_client)

        err = nothing
        try
            AeronTensorPool.Client.await_attach_response(
                tp_client,
                driver_client,
                cid;
                timeout_ns = UInt64(200_000_000),
                retry_interval_ns = UInt64(50_000_000),
                retry_fn = () -> AeronTensorPool.Client.send_attach_request!(
                    driver_client;
                    stream_id = UInt32(10000),
                ),
            )
        catch e
            err = e
        end

        running[] = false
        wait(poll_task)

        @test err isa AttachTimeoutError
        @test count[] >= 2
    end
end
