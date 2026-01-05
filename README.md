# AeronTensorPool.jl

[![CI](https://github.com/DarrylGamroth/AeronTensorPool.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/DarrylGamroth/AeronTensorPool.jl/actions/workflows/ci.yml)
[![Codecov](https://codecov.io/gh/DarrylGamroth/AeronTensorPool.jl/graph/badge.svg)](https://codecov.io/gh/DarrylGamroth/AeronTensorPool.jl)

High-performance shared-memory tensor pool with Aeron control-plane and SBE codecs.

## Features

- SHM header ring + payload pools with seqlock commit protocol.
- Aeron control plane for announce, QoS, attach/detach, and metadata.
- Type-stable, low-allocation hot paths after initialization.
- Driver/client model with producer, consumer, supervisor, and bridge roles.

## Install

```julia
using Pkg
Pkg.add(url="https://github.com/DarrylGamroth/AeronTensorPool.jl")
```

## Quick Start

Driver:

```julia
using AeronTensorPool
cfg = load_driver_config("config/driver.toml")
run_driver(cfg)
```

Producer:

```julia
using AeronTensorPool
cfg = load_producer_config("config/producer.toml")
state = init_producer(cfg)
```

Consumer:

```julia
using AeronTensorPool
cfg = load_consumer_config("config/consumer.toml")
state = init_consumer(cfg)
```

## Docs

- Wire spec: `docs/SHM_Tensor_Pool_Wire_Spec_v1.1.md`
- Driver model: `docs/SHM_Driver_Model_Spec_v1.0.md`
- Implementation notes: `docs/IMPLEMENTATION.md`

## Tests

```bash
julia --project -e 'using Pkg; Pkg.test()'
```
