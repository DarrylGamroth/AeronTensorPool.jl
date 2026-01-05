# Agent Workqueue Repro

Minimal reproduction for intermittent Julia scheduler warning:

```
WARNING: Workqueue inconsistency detected: popfirst!(Workqueue).state !== :runnable
```

## Run

Use multiple threads to increase likelihood of the warning:

```bash
JULIA_NUM_THREADS=4 julia --project repro/agent_workqueue_repro repro/agent_workqueue_repro/repro.jl
```

You can increase iterations to amplify the odds:

```bash
REPRO_ITERS=1000 JULIA_NUM_THREADS=4 julia --project repro/agent_workqueue_repro repro/agent_workqueue_repro/repro.jl
```

## Notes

- The warning is intermittent.
- This uses `AgentRunner` + `CompositeAgent` with a main task that yields while waiting for an atomic flag, similar to usage patterns in AeronTensorPool examples.
