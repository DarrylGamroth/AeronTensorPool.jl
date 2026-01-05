#!/usr/bin/env julia
using Agent

mutable struct CountingAgent
    target::Int
    counter::Int
end

Agent.name(::CountingAgent) = "counting"

function Agent.do_work(agent::CountingAgent)
    agent.counter += 1
    if agent.counter >= agent.target
        throw(AgentTerminationException())
    end
    return 1
end

struct NoopAgent end
Agent.name(::NoopAgent) = "noop"
Agent.do_work(::NoopAgent) = 0

function run_once(target::Int)
    agent = CountingAgent(target, 0)
    composite = CompositeAgent(agent, NoopAgent())
    runner = AgentRunner(BackoffIdleStrategy(), composite)
    Agent.start_on_thread(runner)

    wait(runner)
    return nothing
end

function main()
    iters = parse(Int, get(ENV, "REPRO_ITERS", "100"))
    target = parse(Int, get(ENV, "REPRO_TARGET", "1000"))

    for _ in 1:iters
        run_once(target)
    end
end

main()
