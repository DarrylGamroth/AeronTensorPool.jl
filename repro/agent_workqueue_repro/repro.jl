#!/usr/bin/env julia
using Agent
using Base.Threads

mutable struct CountingAgent
    target::Int
    counter::Int
    done::Atomic{Bool}
end

Agent.name(::CountingAgent) = "counting"

function Agent.do_work(agent::CountingAgent)
    agent.counter += 1
    if agent.counter >= agent.target
        atomic_store!(agent.done, true)
    end
    return 1
end

struct NoopAgent end
Agent.name(::NoopAgent) = "noop"
Agent.do_work(::NoopAgent) = 0

function run_once(target::Int)
    done = Atomic{Bool}(false)
    agent = CountingAgent(target, 0, done)
    composite = CompositeAgent(agent, NoopAgent())
    runner = AgentRunner(BackoffIdleStrategy(), composite)
    Agent.start_on_thread(runner)

    while !atomic_load(done)
        yield()
    end
    close(runner)
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
