# QoS Monitor Plan

Goal: provide an optional QoS monitor helper that subscribes to the QoS stream and maintains last-seen snapshots for producers/consumers. This is a convenience layer above the existing callbacks.

## Scope
- Add a `QosMonitor` type that:
  - owns a QoS subscription and fragment assembler,
  - decodes `QosProducer` and `QosConsumer`,
  - stores last-seen snapshots keyed by producer_id / consumer_id.
- Provide snapshot accessors that return `nothing` if unseen.
- Keep it optional: no changes required to core client/agent flows.

## Phase 1: Types and API
- Define snapshots:
  - `QosProducerSnapshot`: stream_id, producer_id, epoch, current_seq, last_qos_ns.
  - `QosConsumerSnapshot`: stream_id, consumer_id, epoch, mode, last_seq_seen, drops_gap, drops_late, last_qos_ns.
- Define `QosMonitor` fields:
  - Aeron client, subscription, assembler, decoders, clock, maps.
- API:
  - `QosMonitor(config; client)`: builds subscription + assembler.
  - `poll!(monitor, fragment_limit=DEFAULT_FRAGMENT_LIMIT)` → work_count.
  - `producer_qos(monitor, producer_id)` → `Union{Nothing,QosProducerSnapshot}`.
  - `consumer_qos(monitor, consumer_id)` → `Union{Nothing,QosConsumerSnapshot}`.
  - `close(monitor)`.

## Phase 2: Handler implementation
- Build fragment handler that:
  - wraps the SBE header,
  - dispatches by template ID (producer vs consumer),
  - updates the snapshot dicts and last_qos_ns (local clock).
- Ensure type stability: concrete dict value types and decoder reuse.

## Phase 3: Client API wiring (optional helper)
- Add `make_qos_monitor(config; client)` constructor alongside other client helpers.
- Export in `AeronTensorPool`.

## Phase 4: Tests
- Unit tests:
  - feed encoded `QosProducer`/`QosConsumer` into handler and verify snapshots.
  - verify `producer_qos`/`consumer_qos` return `nothing` when absent.
- Integration test (optional):
  - run producer+consumer agents and verify monitor updates.

## Phase 5: Docs
- Add brief usage snippet to `docs/IMPLEMENTATION_GUIDE.md` or a new section.
- Note that QoS is advisory and polling-based.
