## C API Aeron-Style Refactor Plan

Goal: rework the C client API to follow the Aeron C client model (poller + fragment handler callbacks),
without backward compatibility. Aeron is the reference model (`../aeron`).

### Principles
- Poller-driven: users supply a handler; no internal “store last descriptor then read later” state.
- Explicit work loops: functions return work counts (like Aeron).
- Zero allocation: fixed-size buffers and caller-managed storage.
- Clear separation: control-plane polling vs. data-plane polling.
- No hidden threads: caller drives polling.
- Follow `aeron_client_conductor` behavior for polling/work aggregation.
- Keep FragmentAssembler inside the client (handlers receive complete messages).
- When in doubt, mirror Aeron C behavior.

### Phase 0: Inventory + API Surface
- [ ] Identify all current public C APIs and map to Aeron equivalents.
- [ ] Identify internal state that exists only to support “poll then read” usage.
- [ ] Define new public types: `tp_fragment_handler_t`, `tp_control_handler_t`, `tp_frame_handler_t`.
- [ ] Define new poll entry points:
  - `tp_driver_poll(...)`
  - `tp_consumer_poll(...)`
  - `tp_producer_poll(...)`
- [ ] Decide standard return type for pollers (int work count).
- [ ] Decide if controlled fragment handler is needed for backpressure; align with Aeron C conventions.

### Phase 1: Consumer Data Path
- [ ] Replace `tp_consumer_try_read_frame` usage with handler-based read.
- [ ] Implement `tp_consumer_poll` that:
  - polls descriptor subscription,
  - decodes descriptor,
  - reads frame via seqlock immediately,
  - calls user `tp_frame_handler_t`.
- [ ] Remove `last_seq/last_header_index/has_descriptor` from consumer state (or keep only for metrics).
- [ ] Update examples to use handler-based polling.

### Phase 2: Control-Plane Polling
- [ ] Add `tp_consumer_poll_control` (or extend `tp_consumer_poll` with a control handler).
- [ ] Add `tp_producer_poll_control` to handle control-plane responses if needed.
- [ ] Update client attach/detach APIs to mirror Aeron’s explicit poll + response handling.

### Phase 3: Producer Data Path
- [ ] Provide Aeron-style publication helpers:
  - `tp_producer_try_claim` with claim callback,
  - `tp_producer_commit` called explicitly.
- [ ] Ensure `tp_producer_offer_frame` uses the same publish path but is explicitly copy-based.

### Phase 4: Error Handling + State
- [ ] Replace “last response” fields with explicit handler callbacks or query APIs.
- [ ] Ensure all functions return `tp_err_t` and avoid hidden state transitions.
- [ ] Define clear lifecycle: `tp_client_connect` → `tp_*_poll` → `tp_client_close`.

### Phase 5: Tests + Docs
- [ ] Update C integration tests to use handler-driven polling.
- [ ] Update unit tests for control/data pollers.
- [ ] Update examples and docs (`docs/CLIENT_API_MIGRATION.md`).

### Phase 6: Cleanup
- [ ] Remove deprecated functions and state (no backward compatibility).
- [ ] Prune unused helpers now replaced by handler model.
- [ ] Verify conformance matrix entries for C client.

### Tracking
- Status: **Planning**
- This plan should be updated with progress as phases complete.
