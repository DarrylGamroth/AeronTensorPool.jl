# Aeron Tensor Pool Agents (Julia)

> Template-grade reference for LLM/codegen. The code sketches below illustrate patterns (state, lifecycle, Aeron/SBE usage) but are not production-verified; validate against generated codecs and live APIs before shipping. If an LLM can produce cleaner or more idiomatic code, prefer that.

> Steady-state requirement: codegen targets should be type-stable and zero-allocation after initialization; preallocate buffers and avoid runtime dispatch in hot paths.

**Julia packages to reference**
- Aeron.jl (DarrylGamroth fork): Context/Client, add_publication/add_subscription, FragmentHandler/FragmentAssembler, poll
- SBE.jl: generated codecs (wrap!/wrap_and_apply_header!, Encoder/Decoder accessors, repeating groups)
- SBEDomainMapper.jl: schema-to-domain helpers if mapping SBE to richer types (maybe useful but might be easier to use purpose built code)
- Clocks.jl: MonotonicClock + CachedEpochClock, time_nanos/fetch!
- Agent.jl: Agent protocol hooks and poller patterns (if mirroring RtcFramework style)
- RtcFramework.jl (reference only): FragmentAssembler adapters and PollerRegistry usage patterns
- Mmap (stdlib) + Base atomics: mmap SHM and commit_word atomics
- Hsm.jl: hierarchical state machine patterns (if you want explicit agent state machines)

Code generation and implementation templates for the agents in the SHM Tensor Pool spec (v1.1). This guide is optimized for LLM-assisted codegen and human implementers building agents with Julia (Aeron.jl, SBE.jl, Agent.jl). See normative spec: [SHM_Aeron_Tensor_Pool.md](docs/SHM_Aeron_Tensor_Pool.md). For deployment/config/testing, see [IMPLEMENTATION.md](docs/IMPLEMENTATION.md).

## Agent Roles and Responsibilities

### Producer Agent
- **Owns**: Header ring + payload pools (SHM), Aeron publications (descriptor/control/QoS/metadata)
- **Publishes**: `ShmPoolAnnounce`, `FrameDescriptor`, optional `FrameProgress`, `QosProducer`, `DataSourceAnnounce`, `DataSourceMeta`
- **Subscribes**: `ConsumerHello` (optional), supervisor control
- **Core loop**: Acquire frame, write payload, seqlock commit, publish descriptor

### Consumer Agent
- **Owns**: Aeron subscriptions (descriptor/control/QoS), SHM mappings (read-only)
- **Publishes**: `ConsumerHello`, `QosConsumer`
- **Subscribes**: `FrameDescriptor`, optional `FrameProgress`, `ShmPoolAnnounce`, `ConsumerConfig`, `DataSourceMeta`
- **Core loop**: Poll descriptors, seqlock read, process frame, track QoS

### Supervisor Agent
- **Owns**: Aeron publications (control), subscriptions (announce/QoS)
- **Publishes**: `ConsumerConfig`, optional `ControlResponse`
- **Subscribes**: `ShmPoolAnnounce`, `ConsumerHello`, `QosProducer`, `QosConsumer`, `DataSourceAnnounce`
- **Core loop**: Monitor liveness, aggregate QoS, issue config/mode changes

### Bridge Agent (optional)
- **Owns**: Aeron publications (UDP/IPC payload republish), subscriptions (local descriptors), SHM mappings (read-only)
- **Publishes**: Bridged descriptors/payloads on remote channel
- **Subscribes**: `FrameDescriptor`, `ShmPoolAnnounce` (local)
- **Core loop**: Seqlock read, validate, serialize payload, republish

### Decimator Agent (optional)
- **Owns**: Aeron publications (decimated stream), subscriptions (source descriptors)
- **Publishes**: Decimated `FrameDescriptor`, optional suppressed `FrameProgress`
- **Subscribes**: Source `FrameDescriptor`, `ShmPoolAnnounce`
- **Core loop**: Seqlock read, apply decimation ratio, republish subset

---

## Agent Structure Template (Julia)

### Common Agent Skeleton

```julia
using Aeron, Agent, SBE, Clocks
include("gen/TensorPool.jl")  # Generated SBE codecs
using .TensorPool

mutable struct MyAgentState
    # Config (immutable after init)
    config::MyConfig
    
    # Aeron client & subscriptions/publications
    client::Aeron.Client
    pubs::Dict{Symbol, Aeron.Publication}
    subs::Dict{Symbol, Aeron.Subscription}
    
    # Role-specific state (mutable)
    epoch::UInt64
    seq::UInt64
    # ... agent-specific fields
    
    # Preallocated buffers (avoid allocations in hot path)
    msg_buffer::Vector{UInt8}
    frame_buffer::Vector{UInt8}
end

function init_agent(config::MyConfig)
    ctx = Aeron.Context()
    Aeron.aeron_dir!(ctx, config.aeron_dir)
    client = Aeron.Client(ctx)
    
    pubs = Dict{Symbol, Aeron.Publication}()
    subs = Dict{Symbol, Aeron.Subscription}()
    
    # Setup publications/subscriptions based on role
    # pubs[:descriptor] = Aeron.add_publication(client, config.aeron_uri, config.descriptor_stream_id)
    # subs[:control] = Aeron.add_subscription(client, config.aeron_uri, config.control_stream_id)
    
    state = MyAgentState(config, client, pubs, subs, 0, 0, ...)
    return state
end

function work_loop!(state::MyAgentState)
    work_done = false
    
    # Poll subscriptions (dispatch to handlers)
    for (name, sub) in state.subs
        work_done |= poll_subscription!(state, sub, name)
    end
    
    # Perform role-specific work
    work_done |= do_agent_work!(state)
    
    # Emit periodic messages (announces, QoS)
    work_done |= emit_periodic!(state)
    
    return work_done
end

function shutdown!(state::MyAgentState)
    # Close publications/subscriptions
    for pub in values(state.pubs); close(pub); end
    for sub in values(state.subs); close(sub); end
    close(state.client)
    
    # Role-specific cleanup (unlink SHM, etc.)
    cleanup_agent!(state)
end

### Agent.jl Integration (pollers and lifecycle)

```julia
# Example Agent.jl glue using PollerRegistry priorities
Agent.on_start(agent::AbstractMyAgent) = begin
    b = base(agent)
    # Register pollers with priorities (lower = higher priority)
    register!(b.poller_registry, input_poller, 10, :input)
    register!(b.poller_registry, timer_poller, 75, :timer)
    register!(b.poller_registry, control_poller, 200, :control)
end

Agent.do_work(agent::AbstractMyAgent) = begin
    b = base(agent)
    fetch!(b.clock)
    poll(b.poller_registry, agent)
end

Agent.on_close(agent::AbstractMyAgent) = begin
    b = base(agent)
    close(b.counters)
    close(b.comms)
end
```
```

---

## Producer Agent Implementation

### State Structure

```julia
mutable struct ProducerState
    # Config
    config::ProducerConfig
    stream_id::UInt32
    producer_id::UInt32
    clock::Clocks.AbstractClock
    
    # Aeron
    client::Aeron.Client
    pub_descriptor::Aeron.Publication
    pub_control::Aeron.Publication
    pub_qos::Aeron.Publication
    pub_metadata::Aeron.Publication
    sub_control::Aeron.Subscription  # optional: ConsumerHello
    
    # SHM regions
    header_mmap::Vector{UInt8}
    payload_mmaps::Dict{UInt16, Vector{UInt8}}  # pool_id → mmap
    
    # Sequence state
    epoch::UInt64
    seq::UInt64
    layout_version::UInt32
    
    # Progress tracking
    supports_progress::Bool  # any consumer wants it
    progress_interval_ns::UInt64
    progress_bytes_delta::UInt64
    last_progress_ns::UInt64
    
    # Periodic timers
    last_announce_ns::UInt64
    last_qos_ns::UInt64
    
    # Preallocated buffers
    descriptor_buf::Vector{UInt8}
    progress_buf::Vector{UInt8}
    announce_buf::Vector{UInt8}
    qos_buf::Vector{UInt8}
end
```

### Init: Allocate SHM and Write Superblocks

```julia
function init_producer(config::ProducerConfig)
    clock = Clocks.CachedEpochClock(Clocks.MonotonicClock())
    fetch!(clock)

    # Allocate header ring
    header_size = 64 + config.nslots * 256
    header_mmap = mmap_shm(config.header_uri, header_size, write=true)
    
    # Write header superblock (spec §7.1)
    sb = ShmRegionSuperblock.Encoder(header_mmap)
    wrap!(sb, header_mmap, 0)
    magic!(sb, 0x544F504C53484D31)  # "TPOLSHM1" LE
    layoutVersion!(sb, config.layout_version)
    epoch!(sb, UInt64(1))
    streamId!(sb, config.stream_id)
    regionType!(sb, RegionType.HEADER_RING)
    poolId!(sb, UInt16(0))
    nslots!(sb, config.nslots)
    slotBytes!(sb, UInt32(256))
    strideBytes!(sb, UInt32(0))
    pid!(sb, UInt32(getpid()))
    now_ns = UInt64(Clocks.time_nanos(clock))
    startTimestampNs!(sb, now_ns)
    activityTimestampNs!(sb, now_ns)
    
    # Allocate payload pools
    payload_mmaps = Dict{UInt16, Vector{UInt8}}()
    for (pool_id, stride) in enumerate(config.stride_classes)
        pool_size = 64 + config.nslots * stride
        pmmap = mmap_shm(config.payload_uris[pool_id], pool_size, write=true)
        
        psb = ShmRegionSuperblock.Encoder(pmmap)
        wrap!(psb, pmmap, 0)
        magic!(psb, 0x544F504C53484D31)
        layoutVersion!(psb, config.layout_version)
        epoch!(psb, UInt64(1))
        streamId!(psb, config.stream_id)
        regionType!(psb, RegionType.PAYLOAD_POOL)
        poolId!(psb, UInt16(pool_id))
        nslots!(psb, config.nslots)
        slotBytes!(psb, stride)
        strideBytes!(psb, stride)
        pid!(psb, UInt32(getpid()))
        now_ns = UInt64(Clocks.time_nanos(clock))
        startTimestampNs!(psb, now_ns)
        activityTimestampNs!(psb, now_ns)
        
        payload_mmaps[pool_id] = pmmap
    end
    
    # Open Aeron publications
    ctx = Aeron.Context()
    Aeron.aeron_dir!(ctx, config.aeron_dir)
    client = Aeron.Client(ctx)
    
    pub_descriptor = Aeron.add_publication(client, config.aeron_uri, config.descriptor_stream_id)
    pub_control = Aeron.add_publication(client, config.aeron_uri, config.control_stream_id)
    pub_qos = Aeron.add_publication(client, config.aeron_uri, config.qos_stream_id)
    pub_metadata = Aeron.add_publication(client, config.aeron_uri, config.metadata_stream_id)
    
    sub_control = Aeron.add_subscription(client, config.aeron_uri, config.control_stream_id)
    
    state = ProducerState(
        config, config.stream_id, config.producer_id, clock,
        client, pub_descriptor, pub_control, pub_qos, pub_metadata, sub_control,
        header_mmap, payload_mmaps,
        1, 0, config.layout_version,
        false, 250_000, 65536, 0,
        0, 0,
        Vector{UInt8}(undef, 512), Vector{UInt8}(undef, 512),
        Vector{UInt8}(undef, 1024), Vector{UInt8}(undef, 512)
    )
    
    # Emit initial announce
    emit_announce!(state)
    
    return state
end
```

### Core Work: Publish Frame (Spec §15.19)

```julia
function publish_frame!(state::ProducerState, payload_data::AbstractVector{UInt8}, 
                        shape::Vector{Int32}, dtype::Dtype, meta_version::UInt32)
    fetch!(state.clock)

    seq = state.seq
    frame_id = seq  # v1.1: frame_id == seq
    header_index = seq & (state.config.nslots - 1)
    
    # Select pool (smallest stride_bytes >= payload length)
    values_len = length(payload_data)
    pool_id, stride = select_pool(state.config.stride_classes, values_len)
    if isnothing(pool_id)
        @warn "No pool fits payload" values_len
        return  # drop frame
    end
    
    payload_slot = header_index  # v1.1: simple mapping
    payload_mmap = state.payload_mmaps[pool_id]
    
    # 1. Write commit_word = (frame_id << 1) | 1 (WRITING)
    header_offset = 64 + header_index * 256
    commit_ptr = pointer(state.header_mmap, header_offset + 1)
    unsafe_store!(Ptr{UInt64}(commit_ptr), (frame_id << 1) | 1, :release)
    
    # 2. Fill payload bytes
    payload_offset_in_pool = 64 + payload_slot * stride
    copyto!(view(payload_mmap, payload_offset_in_pool+1 : payload_offset_in_pool+values_len), payload_data)
    # Ensure visibility (DMA flush if needed)
    
    # 3. Fill header (all fields except commit_word)
    hdr = TensorSlotHeader256.Encoder(state.header_mmap)
    wrap!(hdr, state.header_mmap, header_offset)
    # Skip commit_word (index 1), fill rest
    frameId!(hdr, frame_id)
    timestampNs!(hdr, UInt64(Clocks.time_nanos(state.clock)))
    metaVersion!(hdr, meta_version)
    valuesLenBytes!(hdr, UInt32(values_len))
    payloadSlot!(hdr, payload_slot)
    payloadOffset!(hdr, UInt32(0))
    poolId!(hdr, pool_id)
    dtype!(hdr, dtype)
    majorOrder!(hdr, MajorOrder.ROW_MAJOR)
    ndims!(hdr, UInt8(length(shape)))
    padAlign!(hdr, UInt8(0))
    # Dims/strides are arrays - need special handling
    for (i, dim) in enumerate(shape)
        dims!(hdr, i-1, dim)  # 0-indexed
    end
    for i in 1:16
        strides!(hdr, i-1, Int32(0))  # 0-indexed
    end
    
    # 4. Write commit_word = (frame_id << 1) (COMMITTED)
    unsafe_store!(Ptr{UInt64}(commit_ptr), frame_id << 1, :release)
    
    # 5. Publish FrameDescriptor
    desc = FrameDescriptor.Encoder(Vector{UInt8})
    wrap_and_apply_header!(desc, state.descriptor_buf, 0)
    streamId!(desc, state.stream_id)
    epoch!(desc, state.epoch)
    seq!(desc, seq)
    headerIndex!(desc, header_index)
    timestampNs!(desc, Clocks.time_nanos(state.clock))
    metaVersion!(desc, meta_version)
    
    Aeron.offer(state.pub_descriptor, view(state.descriptor_buf, 1:sbe_encoded_length(desc)))
    
    # 6. Optional: emit FrameProgress COMPLETE (if supports_progress)
    if state.supports_progress
        emit_progress_complete!(state, frame_id, header_index, values_len)
    end
    
    state.seq += 1
end

function emit_progress_complete!(state::ProducerState, frame_id::UInt64, header_index::UInt32, bytes_filled::UInt64)
    prog = FrameProgress.Encoder(Vector{UInt8})
    wrap_and_apply_header!(prog, state.progress_buf, 0)
    streamId!(prog, state.stream_id)
    epoch!(prog, state.epoch)
    frameId!(prog, frame_id)
    headerIndex!(prog, header_index)
    payloadBytesFilled!(prog, bytes_filled)
    state!(prog, FrameProgressState.COMPLETE)
    Aeron.offer(state.pub_control, view(state.progress_buf, 1:sbe_encoded_length(prog)))
end
```

### Periodic: Announce and QoS

```julia
function emit_periodic!(state::ProducerState)
    fetch!(state.clock)
    now_ns = Clocks.time_nanos(state.clock)
    work_done = false
    
    # Announce (1 Hz)
    if now_ns - state.last_announce_ns >= 1_000_000_000
        emit_announce!(state)
        refresh_activity_timestamps!(state)
        state.last_announce_ns = now_ns
        work_done = true
    end
    
    # QoS (1 Hz)
    if now_ns - state.last_qos_ns >= 1_000_000_000
        emit_qos!(state)
        state.last_qos_ns = now_ns
        work_done = true
    end
    
    return work_done
end

function emit_announce!(state::ProducerState)
    ann = ShmPoolAnnounce.Encoder(Vector{UInt8})
    wrap_and_apply_header!(ann, state.announce_buf, 0)
    streamId!(ann, state.stream_id)
    producerId!(ann, state.producer_id)
    epoch!(ann, state.epoch)
    layoutVersion!(ann, state.layout_version)
    headerRegionUri!(ann, state.config.header_uri)
    headerNslots!(ann, state.config.nslots)
    headerSlotBytes!(ann, UInt16(256))
    maxDims!(ann, state.config.max_dims)
    
    # Add payload_pools group (SBE repeating group API)
    pools_group = payloadPools!(ann, length(state.config.stride_classes))
    for (i, (pool_id, stride)) in enumerate(state.config.stride_classes)
        pool = next!(pools_group)
        poolId!(pool, UInt16(pool_id))
        uri!(pool, state.config.payload_uris[pool_id])
        nslots!(pool, state.config.nslots)
        strideBytes!(pool, stride)
    end
    
    Aeron.offer(state.pub_control, view(state.announce_buf, 1:sbe_encoded_length(ann)))
end

function emit_qos!(state::ProducerState)
    qos = QosProducer.Encoder(Vector{UInt8})
    wrap_and_apply_header!(qos, state.qos_buf, 0)
    streamId!(qos, state.stream_id)
    producerId!(qos, state.producer_id)
    epoch!(qos, state.epoch)
    currentSeq!(qos, state.seq)
    # Optional: watermark, throttle stats
    Aeron.offer(state.pub_qos, view(state.qos_buf, 1:sbe_encoded_length(qos)))
end

function refresh_activity_timestamps!(state::ProducerState)
    fetch!(state.clock)
    now_ns = UInt64(Clocks.time_nanos(state.clock))
    # Header superblock
    sb = ShmRegionSuperblock.Encoder(state.header_mmap)
    wrap!(sb, state.header_mmap, 0)
    activityTimestampNs!(sb, now_ns)
    
    # Payload superblocks
    for pmmap in values(state.payload_mmaps)
        psb = ShmRegionSuperblock.Encoder(pmmap)
        wrap!(psb, pmmap, 0)
        activityTimestampNs!(psb, now_ns)
    end
end

### Aeron Fragment Assembly (subscriptions)

Wrap each subscription in a `FragmentAssembler` and poll via `Aeron.poll` to handle fragmented messages:

```julia
# Example: descriptor subscription adapter
handler = Aeron.FragmentHandler(state) do st, buffer, _
    desc = FrameDescriptor.Decoder(buffer)
    wrap!(desc, buffer, 0, FrameDescriptor.sbe_block_length(), FrameDescriptor.sbe_schema_version())
    handle_descriptor!(st, desc)
    nothing
end

assembler = Aeron.FragmentAssembler(handler)
sub_desc = Aeron.add_subscription(state.client, config.aeron_uri, config.descriptor_stream_id)

function input_poller(state)
    Aeron.poll(sub_desc, assembler, DEFAULT_INPUT_FRAGMENT_COUNT_LIMIT)
end
```

Use distinct assemblers per subscription (control/progress/descriptor) to avoid handler state collisions.
```

### Message Handlers

```julia
function handle_consumer_hello!(state::ProducerState, msg::ConsumerHello.Decoder)
    # Update progress policy if consumer supports_progress
    if supportsProgress(msg) == Bool_.TRUE
        state.supports_progress = true
        # Aggregate hints: take smallest interval/deltas above floor
        pi = progressIntervalUs(msg)
        if pi > 0
            state.progress_interval_ns = min(state.progress_interval_ns, pi * 1000)
        end
        pbd = progressBytesDelta(msg)
        if pbd > 0
            state.progress_bytes_delta = min(state.progress_bytes_delta, pbd)
        end
    end
end
```

## Producer Agent specifics
- Allocate header ring (256-byte slots) and payload pools (fixed stride, same `nslots`), write superblocks, publish `ShmPoolAnnounce` (1 Hz recommended).
- v1.1 canonical identity: `frame_id` in the header, `FrameDescriptor.seq`, and any `FrameProgress.frame_id` MUST be equal for the same frame; producers must write them identically.
- Superblock: 64 bytes fixed; magic `TPOLSHM1` (0x544F504C53484D31 LE); include epoch, layout_version, pid, start_timestamp_ns, activity_timestamp_ns.
- On each frame (normative algorithm §15.19):
  1) `header_index = seq & (nslots - 1)`.
  2) `commit_word = (frame_id << 1) | 1` (store release/relaxed).
  3) Fill payload bytes; ensure visibility (flush DMA if needed).
  4) Fill header (frame_id=seq, shape/strides, pool/slot, meta_version, etc.).
  5) `commit_word = (frame_id << 1)` (store release).
  6) Publish `FrameDescriptor`; optionally `FrameProgress COMPLETE`.
- Progress throttling: emit only if any subscriber supports progress; apply min interval/byte deltas from consumers but not below producer floor (defaults: 250 µs interval, 64 KiB byte delta, rows delta unset).
- Activity timestamp: refresh `activity_timestamp_ns` in superblocks at announce cadence (1 Hz); supervisors timeout at 3–5× cadence.
- Epoch increment: bump on restart or layout change (nslots, slot size, stride classes, superblock size); reset seq/frame_id to 0.

## Consumer Agent specifics
- Map SHM URIs from `ShmPoolAnnounce`; backend validation (§15.22): reject unknown schemes, verify hugepages if `require_hugepages=true`, validate stride_bytes is power-of-two and multiple of page size.
- Validate superblocks: magic=`TPOLSHM1`, layout_version, epoch, nslots, slot_bytes=256, stride_bytes, region_type, pool_id, little-endian only.
- State machine (§15.21): UNMAPPED → MAPPED(epoch); remap on epoch change, drop all in-flight frames on transition.
- On `FrameDescriptor` (normative algorithm §15.19): validate epoch, compute header_index, seqlock protocol:
  1) Read `commit_word` (acquire); odd? DROP.
  2) Read header + payload.
  3) Re-read `commit_word` (acquire); changed or odd? DROP (count `drops_late`).
  4) Accept only if commit_word unchanged, even, AND header `frame_id` == `FrameDescriptor.seq`; otherwise DROP.
- Track `drops_gap` (seq gaps) and `drops_late` (seqlock failures) for `QosConsumer`; optional `max_outstanding_seq_gap` (default: 256 frames) to trigger resync.
- Modes:
  - STREAM: process all descriptors.
  - LATEST: keep newest only (evict older pending work).
  - DECIMATED: process every Nth (per `decimation`); MAY ignore progress for dropped frames.
- Remap on epoch/layout mismatch (§15.19 remap algorithm); fallback to payload_fallback_uri if provided and SHM rejected.
- FrameDescriptor remains the canonical “frame available” signal; consumers MUST NOT treat `FrameProgress` (including COMPLETE) as a substitute. Producers MAY omit `FrameProgress` entirely.

---

## Supervisor Agent Implementation

### State Structure

```julia
mutable struct SupervisorState
    # Config
    config::SupervisorConfig
    clock::Clocks.AbstractClock
    
    # Aeron
    aeron::Aeron.Client
    sub_announce::Aeron.Subscription
    sub_qos::Aeron.Subscription
    pub_control::Aeron.Publication
    
    # Tracked producers
    producers::Dict{UInt32, ProducerInfo}  # producer_id → info
    
    # Tracked consumers
    consumers::Dict{UInt32, ConsumerInfo}  # consumer_id → info
    
    # Liveness timeout
    liveness_timeout_ns::UInt64
    
    # Preallocated buffers
    config_buf::Vector{UInt8}
end

struct ProducerInfo
    stream_id::UInt32
    epoch::UInt64
    last_announce_ns::UInt64
    last_qos_ns::UInt64
    current_seq::UInt64
end

struct ConsumerInfo
    stream_id::UInt32
    consumer_id::UInt32
    epoch::UInt64
    mode::ConsumerMode
    last_hello_ns::UInt64
    last_qos_ns::UInt64
    last_seq_seen::UInt64
    drops_gap::UInt64
    drops_late::UInt64
end
```

### Message Handlers

```julia
function handle_shm_pool_announce!(state::SupervisorState, msg::ShmPoolAnnounce.Decoder)
    fetch!(state.clock)
    now_ns = Clocks.time_nanos(state.clock)
    
    pid = producerId(msg)
    ep = epoch(msg)
    info = get(state.producers, pid, nothing)
    if isnothing(info) || info.epoch != ep
        # New or restarted producer
        @info "Producer registered/restarted" producer_id=pid epoch=ep
    end
    
    state.producers[pid] = ProducerInfo(
        streamId(msg), ep, now_ns, 
        get(info, :last_qos_ns, 0),
        get(info, :current_seq, 0)
    )
end

function handle_qos_producer!(state::SupervisorState, msg::QosProducer.Decoder)
    fetch!(state.clock)
    pid = producerId(msg)
    info = get(state.producers, pid, nothing)
    if !isnothing(info)
        state.producers[pid] = ProducerInfo(
            info.stream_id, epoch(msg), info.last_announce_ns, 
            Clocks.time_nanos(state.clock), currentSeq(msg)
        )
    end
end

function handle_consumer_hello!(state::SupervisorState, msg::ConsumerHello.Decoder)
    fetch!(state.clock)
    now_ns = Clocks.time_nanos(state.clock)
    
    # Detect consumer ID collision (multiple hellos same ID, different source)
    cid = consumerId(msg)
    existing = get(state.consumers, cid, nothing)
    if !isnothing(existing) && existing.last_hello_ns + 5_000_000_000 > now_ns
        @warn "Possible consumer ID collision" consumer_id=cid
    end
    
    state.consumers[cid] = ConsumerInfo(
        streamId(msg), cid, 0, mode(msg),
        now_ns, 0, 0, 0, 0
    )
    
    # Optional: issue ConsumerConfig (force mode, fallback_uri)
    # issue_consumer_config!(state, cid, ...)
end

function handle_qos_consumer!(state::SupervisorState, msg::QosConsumer.Decoder)
    cid = consumerId(msg)
    info = get(state.consumers, cid, nothing)
    if !isnothing(info)
        state.consumers[cid] = ConsumerInfo(
            info.stream_id, cid, epoch(msg), info.mode,
            info.last_hello_ns, Clocks.time_nanos(state.clock), 
            lastSeqSeen(msg), dropsGap(msg), dropsLate(msg)
        )
    end
end
```

### Periodic: Liveness Check

```julia
function check_liveness!(state::SupervisorState)
    fetch!(state.clock)
    now_ns = Clocks.time_nanos(state.clock)
    
    # Producers stale?
    for (pid, info) in state.producers
        if now_ns - info.last_announce_ns > state.liveness_timeout_ns
            @warn "Producer stale" producer_id=pid last_seen=(now_ns - info.last_announce_ns)/1e9
        end
    end
    
    # Consumers stale?
    for (cid, info) in state.consumers
        if now_ns - info.last_qos_ns > state.liveness_timeout_ns
            @warn "Consumer stale" consumer_id=cid last_seen=(now_ns - info.last_qos_ns)/1e9
        end
    end
    
    # Check QoS metrics (drops_gap, drops_late thresholds)
    for (cid, info) in state.consumers
        if info.drops_gap > 100
            @warn "High gap drops" consumer_id=cid drops_gap=info.drops_gap
        end
        if info.drops_late > 100
            @warn "High late drops" consumer_id=cid drops_late=info.drops_late
        end
    end
end

function issue_consumer_config!(state::SupervisorState, consumer_id::UInt32, mode::ConsumerMode, 
                                decimation::UInt16=1, fallback_uri::String="")
    cfg = ConsumerConfig.Encoder(state.config_buf)
    wrap_and_apply_header!(cfg, state.config_buf, 0)
    streamId!(cfg, state.config.stream_id)
    consumerId!(cfg, consumer_id)
    useShm!(cfg, Bool_.TRUE)
    mode!(cfg, mode)
    decimation!(cfg, decimation)
    payloadFallbackUri!(cfg, fallback_uri)
    
    Aeron.offer(state.pub_control, view(state.config_buf, 1:sbe_encoded_length(cfg)))
    @info "Issued ConsumerConfig" consumer_id mode decimation
end
```

---

## Bridge Agent Implementation (Optional)

### Responsibilities
- Subscribe to local descriptors + SHM
- Seqlock read and validate
- Republish payload over Aeron UDP (or other transport) with its own descriptors/epoch

### State Structure

```julia
mutable struct BridgeState
    # Source (local SHM)
    consumer_state::ConsumerState  # reuse consumer mapping/seqlock
    
    # Destination (bridged channel)
    bridge_aeron::Aeron.Client
    bridge_pub_descriptor::Aeron.Publication
    bridge_pub_payload::Aeron.Publication
    
    # Bridge identity
    bridge_epoch::UInt64
    bridge_seq::UInt64
end
```

### Core Work: Validate and Republish

```julia
function bridge_frame!(state::BridgeState, hdr::TensorSlotHeader256, payload::AbstractVector{UInt8})
    # Preserve seq/frame_id from source
    source_seq = frameId(hdr)
    
    # Serialize payload to Aeron message
    # (chunk if needed, or use large MTU for IPC/UDP)
    Aeron.offer(state.bridge_pub_payload, payload)
    
    # Publish bridged descriptor (with bridge's own epoch)
    desc = FrameDescriptor.Encoder(state.descriptor_buf)
    wrap_and_apply_header!(desc, state.descriptor_buf, 0)
    streamId!(desc, state.consumer_state.stream_id)
    epoch!(desc, state.bridge_epoch)
    seq!(desc, source_seq)  # preserve
    headerIndex!(desc, UInt32(0))  # not used in bridge mode
    timestampNs!(desc, hdr.timestampNs)
    metaVersion!(desc, hdr.metaVersion)
    
    Aeron.offer(state.bridge_pub_descriptor, view(state.descriptor_buf, 1:sbe_encoded_length(desc)))
end
```

---

## Decimator Agent Implementation (Optional)

### Responsibilities
- Subscribe to source descriptors + SHM
- Apply decimation ratio (accept every Nth frame)
- Republish subset with same seq/frame_id
- Optional: suppress FrameProgress for dropped frames

### State Structure

```julia
mutable struct DecimatorState
    consumer_state::ConsumerState  # reuse consumer
    decimation_ratio::UInt16
    frame_counter::UInt64
    
    # Republish channel
    decimator_pub_descriptor::Aeron.Publication
end
```

### Core Work: Decimated Republish

```julia
function handle_decimated_frame!(state::DecimatorState, hdr::TensorSlotHeader256, payload::AbstractVector{UInt8})
    state.frame_counter += 1
    
    if state.frame_counter % state.decimation_ratio == 0
        # Accept and republish
        republish_frame!(state, hdr, payload)
    else
        # Drop (no progress)
    end
end

function republish_frame!(state::DecimatorState, hdr::TensorSlotHeader256, payload::AbstractVector{UInt8})
    # Emit descriptor with preserved seq/frame_id
    desc = FrameDescriptor.Encoder(state.descriptor_buf)
    wrap_and_apply_header!(desc, state.descriptor_buf, 0)
    streamId!(desc, state.consumer_state.stream_id)
    epoch!(desc, state.consumer_state.mapped_epoch)
    seq!(desc, frameId(hdr))  # preserve
    headerIndex!(desc, payloadSlot(hdr))
    timestampNs!(desc, timestampNs(hdr))
    metaVersion!(desc, metaVersion(hdr))
    
    Aeron.offer(state.decimator_pub_descriptor, view(state.descriptor_buf, 1:sbe_encoded_length(desc)))
end
```

---

## Utility Functions

### SHM Helpers

```julia
function mmap_shm(uri::String, size::Int; write::Bool=false)
    # Parse shm:file?path=... URI
    path = parse_shm_uri(uri)
    
    # Open file
    fd = open(path, write ? "r+" : "r")
    
    # mmap
    prot = write ? (Mmap.PROT_READ | Mmap.PROT_WRITE) : Mmap.PROT_READ
    mmap_vec = Mmap.mmap(fd, Vector{UInt8}, size, 0, prot=prot)
    
    close(fd)
    return mmap_vec
end

function parse_shm_uri(uri::String)
    # Simple parser: "shm:file?path=/dev/hugepages/tp_pool|require_hugepages=true"
    # Extract path parameter
    m = match(r"shm:file\?path=([^|&]+)", uri)
    isnothing(m) && error("Invalid shm:file URI: $uri")
    return m.captures[1]
end

function validate_uri(uri::String)
    # Backend validation (spec §15.22)
    startswith(uri, "shm:file?") || return false
    # Check for unknown params
    params = split(split(uri, '?')[2], '|')
    for p in params
        key = split(p, '=')[1]
        key in ["path", "require_hugepages"] || return false
    end
    return true
end

function select_pool(stride_classes::Vector{UInt32}, values_len::Int)
    for (i, stride) in enumerate(stride_classes)
        if stride >= values_len
            return (UInt16(i), stride)
        end
    end
    return (nothing, 0)
end
```

### Atomic Helpers (if needed for commit_word)

```julia
# Use Base atomic functions or llvmcall for acquire/release semantics
# Example: unsafe_load/unsafe_store with ordering

function atomic_load_u64(ptr::Ptr{UInt64}, ordering::Symbol=:acquire)
    # Julia 1.7+ supports atomic ordering on unsafe_load
    return unsafe_load(ptr, ordering)
end

function atomic_store_u64!(ptr::Ptr{UInt64}, val::UInt64, ordering::Symbol=:release)
    unsafe_store!(ptr, val, ordering)
end
```

---

---

For deployment, ops, and detailed test plans, see [docs/IMPLEMENTATION.md](docs/IMPLEMENTATION.md).
