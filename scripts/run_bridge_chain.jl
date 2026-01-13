#!/usr/bin/env julia
using Agent
using Aeron
using AeronTensorPool
using Logging

Base.exit_on_sigint(false)

struct ProducerWork
    state::ProducerState
    control_assembler::Aeron.FragmentAssembler
    qos_assembler::Aeron.FragmentAssembler
end

Agent.name(::ProducerWork) = "bridge-producer-work"

function Agent.do_work(agent::ProducerWork)
    return Producer.producer_do_work!(agent.state, agent.control_assembler, agent.qos_assembler)
end

Agent.on_close(::ProducerWork) = nothing

function usage()
    println("Usage: julia --project scripts/run_bridge_chain.jl [bridge_a] [bridge_b] [duration_s]")
end

function ensure_shm_dirs(config::ProducerConfig)
    mkpath(dirname(parse_shm_uri(config.header_uri).path))
    for pool in config.payload_pools
        mkpath(dirname(parse_shm_uri(pool.uri).path))
    end
    return nothing
end

function with_embedded_media_driver(f::Function)
    Aeron.MediaDriver.launch_embedded() do driver
        f(driver)
    end
end

function run_chain(bridge_a_path::String, bridge_b_path::String, duration_s::Float64)
    bridge_a_cfg, bridge_a_mappings = Bridge.load_bridge_config(bridge_a_path)
    bridge_b_cfg, bridge_b_mappings = Bridge.load_bridge_config(bridge_b_path)
    isempty(bridge_a_mappings) && error("bridge A config has no mappings")
    isempty(bridge_b_mappings) && error("bridge B config has no mappings")

    mapping_a = bridge_a_mappings[1]
    mapping_b = bridge_b_mappings[1]

    with_embedded_media_driver() do driver
        aeron_dir = Aeron.MediaDriver.aeron_dir(driver)
        bridge_a_cfg.aeron_dir = isempty(bridge_a_cfg.aeron_dir) ? aeron_dir : bridge_a_cfg.aeron_dir
        bridge_b_cfg.aeron_dir = isempty(bridge_b_cfg.aeron_dir) ? aeron_dir : bridge_b_cfg.aeron_dir

        mktempdir() do root_dir
            prod_dir = joinpath(root_dir, "producer")
            bridge_a_dir = joinpath(root_dir, "bridge-a")
            bridge_b_dir = joinpath(root_dir, "bridge-b")

            producer_cfg = default_producer_config(;
                aeron_dir = aeron_dir,
                stream_id = mapping_a.source_stream_id,
                shm_base_dir = prod_dir,
                producer_instance_id = "bridge-chain-producer",
            )
            header_uri, pools = AeronTensorPool.resolve_producer_paths(
                producer_cfg.header_uri,
                producer_cfg.payload_pools,
                producer_cfg.shm_base_dir,
                producer_cfg.shm_namespace,
                producer_cfg.producer_instance_id,
                UInt64(1),
            )
            producer_cfg = ProducerConfig(
                producer_cfg.aeron_dir,
                producer_cfg.aeron_uri,
                producer_cfg.descriptor_stream_id,
                producer_cfg.control_stream_id,
                producer_cfg.qos_stream_id,
                producer_cfg.metadata_stream_id,
                producer_cfg.stream_id,
                producer_cfg.producer_id,
                producer_cfg.layout_version,
                producer_cfg.nslots,
                producer_cfg.shm_base_dir,
                producer_cfg.shm_namespace,
                producer_cfg.producer_instance_id,
                header_uri,
                pools,
                producer_cfg.max_dims,
                producer_cfg.announce_interval_ns,
                producer_cfg.qos_interval_ns,
                producer_cfg.progress_interval_ns,
                producer_cfg.progress_bytes_delta,
                producer_cfg.mlock_shm,
            )
            ensure_shm_dirs(producer_cfg)

            bridge_a_consumer_cfg = default_consumer_config(;
                aeron_dir = aeron_dir,
                stream_id = mapping_a.source_stream_id,
                shm_base_dir = prod_dir,
            )
            bridge_a_producer_cfg = default_producer_config(;
                aeron_dir = aeron_dir,
                stream_id = mapping_a.dest_stream_id,
                shm_base_dir = bridge_a_dir,
                producer_instance_id = "bridge-chain-a",
            )
            header_uri, pools = AeronTensorPool.resolve_producer_paths(
                bridge_a_producer_cfg.header_uri,
                bridge_a_producer_cfg.payload_pools,
                bridge_a_producer_cfg.shm_base_dir,
                bridge_a_producer_cfg.shm_namespace,
                bridge_a_producer_cfg.producer_instance_id,
                UInt64(1),
            )
            bridge_a_producer_cfg = ProducerConfig(
                bridge_a_producer_cfg.aeron_dir,
                bridge_a_producer_cfg.aeron_uri,
                bridge_a_producer_cfg.descriptor_stream_id,
                bridge_a_producer_cfg.control_stream_id,
                bridge_a_producer_cfg.qos_stream_id,
                bridge_a_producer_cfg.metadata_stream_id,
                bridge_a_producer_cfg.stream_id,
                bridge_a_producer_cfg.producer_id,
                bridge_a_producer_cfg.layout_version,
                bridge_a_producer_cfg.nslots,
                bridge_a_producer_cfg.shm_base_dir,
                bridge_a_producer_cfg.shm_namespace,
                bridge_a_producer_cfg.producer_instance_id,
                header_uri,
                pools,
                bridge_a_producer_cfg.max_dims,
                bridge_a_producer_cfg.announce_interval_ns,
                bridge_a_producer_cfg.qos_interval_ns,
                bridge_a_producer_cfg.progress_interval_ns,
                bridge_a_producer_cfg.progress_bytes_delta,
                bridge_a_producer_cfg.mlock_shm,
            )
            ensure_shm_dirs(bridge_a_producer_cfg)

            bridge_b_consumer_cfg = default_consumer_config(;
                aeron_dir = aeron_dir,
                stream_id = mapping_b.source_stream_id,
                shm_base_dir = bridge_a_dir,
            )
            bridge_b_producer_cfg = default_producer_config(;
                aeron_dir = aeron_dir,
                stream_id = mapping_b.dest_stream_id,
                shm_base_dir = bridge_b_dir,
                producer_instance_id = "bridge-chain-b",
            )
            header_uri, pools = AeronTensorPool.resolve_producer_paths(
                bridge_b_producer_cfg.header_uri,
                bridge_b_producer_cfg.payload_pools,
                bridge_b_producer_cfg.shm_base_dir,
                bridge_b_producer_cfg.shm_namespace,
                bridge_b_producer_cfg.producer_instance_id,
                UInt64(1),
            )
            bridge_b_producer_cfg = ProducerConfig(
                bridge_b_producer_cfg.aeron_dir,
                bridge_b_producer_cfg.aeron_uri,
                bridge_b_producer_cfg.descriptor_stream_id,
                bridge_b_producer_cfg.control_stream_id,
                bridge_b_producer_cfg.qos_stream_id,
                bridge_b_producer_cfg.metadata_stream_id,
                bridge_b_producer_cfg.stream_id,
                bridge_b_producer_cfg.producer_id,
                bridge_b_producer_cfg.layout_version,
                bridge_b_producer_cfg.nslots,
                bridge_b_producer_cfg.shm_base_dir,
                bridge_b_producer_cfg.shm_namespace,
                bridge_b_producer_cfg.producer_instance_id,
                header_uri,
                pools,
                bridge_b_producer_cfg.max_dims,
                bridge_b_producer_cfg.announce_interval_ns,
                bridge_b_producer_cfg.qos_interval_ns,
                bridge_b_producer_cfg.progress_interval_ns,
                bridge_b_producer_cfg.progress_bytes_delta,
                bridge_b_producer_cfg.mlock_shm,
            )
            ensure_shm_dirs(bridge_b_producer_cfg)

            consumer_cfg = default_consumer_config(;
                aeron_dir = aeron_dir,
                stream_id = mapping_b.dest_stream_id,
                shm_base_dir = bridge_b_dir,
            )

            Aeron.Context() do context
                Aeron.aeron_dir!(context, aeron_dir)
                Aeron.Client(context) do client
                    producer_agent = ProducerAgent(producer_cfg; client = client)
                    bridge_a_agent = BridgeAgent(
                        bridge_a_cfg,
                        mapping_a,
                        bridge_a_consumer_cfg,
                        bridge_a_producer_cfg;
                        client = client,
                    )
                    bridge_b_agent = BridgeAgent(
                        bridge_b_cfg,
                        mapping_b,
                        bridge_b_consumer_cfg,
                        bridge_b_producer_cfg;
                        client = client,
                    )

                    received = Ref(0)
                    callbacks = let received = received
                        ConsumerCallbacks(; on_frame! = (_, _) -> (received[] += 1))
                    end
                    consumer_agent = ConsumerAgent(consumer_cfg; client = client, callbacks = callbacks)

                    producer_invoker = AgentInvoker(producer_agent)
                    bridge_a_invoker = AgentInvoker(bridge_a_agent)
                    bridge_b_invoker = AgentInvoker(bridge_b_agent)
                    consumer_invoker = AgentInvoker(consumer_agent)
                    bridge_a_prod_invoker = AgentInvoker(
                        ProducerWork(
                            bridge_a_agent.receiver.producer_state,
                            Producer.make_control_assembler(bridge_a_agent.receiver.producer_state),
                            Producer.make_qos_assembler(bridge_a_agent.receiver.producer_state),
                        ),
                    )
                    bridge_b_prod_invoker = AgentInvoker(
                        ProducerWork(
                            bridge_b_agent.receiver.producer_state,
                            Producer.make_control_assembler(bridge_b_agent.receiver.producer_state),
                            Producer.make_qos_assembler(bridge_b_agent.receiver.producer_state),
                        ),
                    )

                    Agent.start(producer_invoker)
                    Agent.start(bridge_a_invoker)
                    Agent.start(bridge_b_invoker)
                    Agent.start(consumer_invoker)
                    Agent.start(bridge_a_prod_invoker)
                    Agent.start(bridge_b_prod_invoker)

                    payload = fill(UInt8(1), 1024)
                    shape = Int32[1024]
                    strides = Int32[1]

                    wait_start = time_ns()
                    wait_limit = wait_start + Int64(5e9)
                    while (bridge_a_agent.sender.consumer_state.mappings.header_mmap === nothing ||
                           bridge_b_agent.sender.consumer_state.mappings.header_mmap === nothing ||
                           consumer_agent.state.mappings.header_mmap === nothing) &&
                          time_ns() < wait_limit
                        Agent.invoke(producer_invoker)
                        Agent.invoke(bridge_a_invoker)
                        Agent.invoke(bridge_b_invoker)
                        Agent.invoke(consumer_invoker)
                        Agent.invoke(bridge_a_prod_invoker)
                        Agent.invoke(bridge_b_prod_invoker)
                        yield()
                    end

                    start = time_ns()
                    end_limit = start + Int64(round(duration_s * 1e9))
                    while time_ns() < end_limit
                        Agent.invoke(producer_invoker)
                        Agent.invoke(bridge_a_invoker)
                        Agent.invoke(bridge_b_invoker)
                        Agent.invoke(consumer_invoker)
                        Agent.invoke(bridge_a_prod_invoker)
                        Agent.invoke(bridge_b_prod_invoker)
                        if bridge_a_agent.sender.consumer_state.mappings.header_mmap !== nothing
                            Producer.offer_frame!(producer_agent.state, payload, shape, strides, Dtype.UINT8, UInt32(0))
                        end
                        received[] > 0 && break
                        yield()
                    end

                    if received[] == 0
                        error("Bridge chain test did not receive frames")
                    end
                    @info "Bridge chain test received frames" count = received[]

                    close(consumer_invoker)
                    close(bridge_b_invoker)
                    close(bridge_a_invoker)
                    close(producer_invoker)
                    close(bridge_b_prod_invoker)
                    close(bridge_a_prod_invoker)
                end
            end
        end
    end
    return nothing
end

function run_chain_main(args::Vector{String})
    bridge_a = length(args) >= 1 ? args[1] : "config/bridge_chain_a_example.toml"
    bridge_b = length(args) >= 2 ? args[2] : "config/bridge_chain_b_example.toml"
    duration_s = length(args) >= 3 ? parse(Float64, args[3]) : 5.0
    run_chain(bridge_a, bridge_b, duration_s)
    return 0
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_chain_main(ARGS)
end
