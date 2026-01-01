@testset "System smoke test" begin
    with_embedded_driver() do driver
        mktempdir("/dev/shm") do dir
            config_path = joinpath(dir, "config.toml")
            open(config_path, "w") do io
                write(
                    io,
                    """
[producer]
aeron_dir = "/dev/shm/aeron-\${USER}"
aeron_uri = "aeron:ipc"
descriptor_stream_id = 1100
control_stream_id = 1000
qos_stream_id = 1200
metadata_stream_id = 1300
stream_id = 1
producer_id = 7
layout_version = 1
nslots = 8
shm_base_dir = "$(dir)"
shm_namespace = "tensorpool"
producer_instance_id = "test-producer"
header_uri = ""
max_dims = 8
announce_interval_ns = 1000000000
qos_interval_ns = 1000000000
progress_interval_ns = 250000
progress_bytes_delta = 65536

[[producer.payload_pools]]
pool_id = 1
uri = ""
stride_bytes = 4096
nslots = 8

[consumer]
aeron_dir = "/dev/shm/aeron-\${USER}"
aeron_uri = "aeron:ipc"
descriptor_stream_id = 1100
control_stream_id = 1000
qos_stream_id = 1200
stream_id = 1
consumer_id = 42
expected_layout_version = 1
max_dims = 8
mode = "STREAM"
decimation = 1
use_shm = true
supports_shm = true
supports_progress = false
max_rate_hz = 0
payload_fallback_uri = ""
shm_base_dir = "$(dir)"
allowed_base_dirs = ["$(dir)"]
require_hugepages = false
progress_interval_us = 250
progress_bytes_delta = 65536
progress_rows_delta = 0
hello_interval_ns = 1000000000
qos_interval_ns = 1000000000

[supervisor]
aeron_dir = "/dev/shm/aeron-\${USER}"
aeron_uri = "aeron:ipc"
control_stream_id = 1000
qos_stream_id = 1200
stream_id = 1
liveness_timeout_ns = 5000000000
liveness_check_interval_ns = 1000000000
""",
                )
            end

            env = Dict(ENV)
            env["AERON_DIR"] = Aeron.MediaDriver.aeron_dir(driver)
            system = load_system_config(config_path; env = env)

            producer = init_producer(system.producer)
            consumer = init_consumer(system.consumer)
            supervisor = init_supervisor(system.supervisor)
            try

            prod_ctrl = make_control_assembler(producer)
            cons_ctrl = make_control_assembler(consumer)
            got_frame = Ref(false)
            cons_desc = Aeron.FragmentAssembler(Aeron.FragmentHandler(consumer) do st, buffer, _
                header = MessageHeader.Decoder(buffer, 0)
                if MessageHeader.templateId(header) == TEMPLATE_FRAME_DESCRIPTOR
                    FrameDescriptor.wrap!(st.desc_decoder, buffer, 0; header = header)
                    result = try_read_frame!(st, st.desc_decoder)
                    result && (got_frame[] = true)
                end
                nothing
            end)

            sup_ctrl = make_control_assembler(supervisor)
            sup_qos = Aeron.FragmentAssembler(Aeron.FragmentHandler(supervisor) do st, buffer, _
                header = MessageHeader.Decoder(buffer, 0)
                template_id = MessageHeader.templateId(header)
                if template_id == TEMPLATE_QOS_PRODUCER
                    QosProducer.wrap!(st.qos_producer_decoder, buffer, 0; header = header)
                    AeronTensorPool.handle_qos_producer!(st, st.qos_producer_decoder)
                elseif template_id == TEMPLATE_QOS_CONSUMER
                    QosConsumer.wrap!(st.qos_consumer_decoder, buffer, 0; header = header)
                    AeronTensorPool.handle_qos_consumer!(st, st.qos_consumer_decoder)
                end
                nothing
            end)

            payload = UInt8[1, 2, 3, 4]
            shape = Int32[4]
            strides = Int32[1]
            published = false

            ok = wait_for() do
                producer_do_work!(producer, prod_ctrl)
                consumer_do_work!(consumer, cons_desc, cons_ctrl)
                supervisor_do_work!(supervisor, sup_ctrl, sup_qos)

                if !published && consumer.mappings.header_mmap !== nothing
                    publish_frame!(producer, payload, shape, strides, Dtype.UINT8, UInt32(0))
                    published = true
                end
                return published && got_frame[]
            end

            @test ok
            finally
                close_producer_state!(producer)
                close_consumer_state!(consumer)
                close_supervisor_state!(supervisor)
            end
        end
    end
end
