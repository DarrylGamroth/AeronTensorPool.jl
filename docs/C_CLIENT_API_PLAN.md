# C Client API Plan

This plan defines the initial C client implementation for AeronTensorPool. It follows Aeron C client conventions (context + connect + poll/invoker), while adhering to the driver and wire specs.

## 0. Goals
- Provide a minimal, stable C API to attach producers/consumers to a Julia driver.
- Preserve zero-allocation hot paths after initialization.
- Mirror Aeron’s API style (`context`, `connect`, `do_work`, `close`) for user familiarity.
- Avoid policy decisions outside the specs; rely on driver responses and `ShmPoolAnnounce`.

## 1. Repository Layout (proposed)
- `c/` (new top-level folder for C client)
  - `include/`
    - `tensorpool_client.h` (public API)
    - `tensorpool_types.h` (public structs/enums)
    - `tensorpool_errors.h`
  - `src/`
    - `tp_context.c/.h`
    - `tp_client.c/.h`
    - `tp_driver_control.c/.h` (attach/detach/keepalive)
    - `tp_consumer.c/.h` (descriptor polling + seqlock read)
    - `tp_producer.c/.h` (slot claim + commit)
    - `tp_shm.c/.h` (mmap, validation, superblocks)
    - `tp_discovery.c/.h` (optional discovery client)
    - `tp_qos.c/.h` (optional QoS monitor)
    - `tp_metadata.c/.h` (optional metadata cache)
  - `tests/` (C tests; integration against Julia driver)
  - `CMakeLists.txt` (preferred build system for v1)

## 2. Public API Shape (Aeron-style)
### Context + Client
- `tp_context_t` (configuration container)
  - set/get for `aeron_dir`, control channel/stream, discovery endpoints, timeouts
- `tp_client_t`
  - `tp_context_init`, `tp_context_close`
  - `tp_client_connect(tp_context_t*, tp_client_t**)`
  - `tp_client_do_work(tp_client_t*)`
  - `tp_client_close(tp_client_t*)`

### Driver Attach
- `tp_attach_producer(...)` / `tp_attach_consumer(...)`
  - returns `tp_producer_t*` / `tp_consumer_t*`
  - uses control-plane SBE (`ShmAttachRequest/Response`)
- `tp_attach_request_t` for async-style attach
  - `tp_send_attach_request(...)`
  - `tp_poll_attach_response(...)`

### Producer API
- `tp_try_claim_slot(tp_producer_t*, uint16_t pool_id, tp_slot_claim_t*)`
- `tp_try_claim_slot_by_size(tp_producer_t*, size_t values_len, tp_slot_claim_t*)`
- `tp_commit_slot(tp_producer_t*, tp_slot_claim_t*, size_t values_len, ...)`
- `tp_offer_frame(tp_producer_t*, const uint8_t* data, size_t len, ...)`

### Consumer API
- `tp_poll_descriptors(tp_consumer_t*, int fragment_limit)`
- `tp_try_read_frame(tp_consumer_t*, tp_frame_view_t*)` (seqlock protocol)
- Callbacks (optional): `tp_consumer_set_on_frame(...)`

### Discovery/QoS/Metadata (optional)
- `tp_discovery_client_t`: `tp_discover_streams(...)`, `tp_poll_discovery_response(...)`
- `tp_qos_monitor_t`: `tp_poll_qos(...)`, `tp_get_producer_qos(...)`, `tp_get_consumer_qos(...)`
- `tp_metadata_cache_t`: `tp_poll_metadata(...)`, `tp_get_metadata(...)`

## 3. Wire/Driver Compliance
Must implement client rules from:
- `docs/SHM_Tensor_Pool_Wire_Spec_v1.1.md`
- `docs/SHM_Driver_Model_Spec_v1.0.md`
- `docs/SHM_Discovery_Service_Spec_v_1.0.md` (optional)

Key MUSTs:
- Validate `ShmAttachResponse` required fields (non-null, non-empty URIs).
- Validate superblocks, seqlock protocol, `frame_id == seq`.
- On protocol errors: fail closed, drop mappings, reattach.
- `ShmLeaseKeepalive` cadence and expiry rules.

## 4. SBE Codec Strategy
- Use `../simple-binary-encoding` with the Java `sbe-tool` for C codegen.
- Generate codecs into `c/gen/` and keep them in the repo for deterministic builds.
- Provide thin wrapper functions for:
  - wrap + apply header
  - group iterators (avoid allocations)
  - varData access (avoid copies)

## 5. Concurrency & Invoker Mode
- Expose `tp_client_do_work` for invoker-style integration.
- Allow a background thread runner if needed (like Aeron agent runner).
- Thread-safety: `tp_client_do_work` is not re-entrant; require caller-side serialization.

## 6. SHM Handling
- `tp_shm_map(uri, size, readonly)` + `tp_shm_unmap`
- `tp_shm_validate_superblock` (magic/layout/epoch/region_type)
- `tp_shm_validate_uri` (scheme/params/hugepages)
- optional `mlock` per process if enabled by driver policies

## 7. Testing Strategy
- Unit tests for:
  - URI parsing and validation
  - superblock encode/decode
  - seqlock read path
  - attach response validation
- Integration tests:
  - Start Julia driver + C client attach
  - Producer->Consumer loop with SHM
  - Discovery + attach flow

## 8. Deliverables (phased, v1 minimal)
### Phase 1: Core attach + SHM
- Implement `tp_context`, `tp_client`, driver control attach/detach/keepalive.
- SHM mapping + superblock validation.
- Simple consumer read loop.
Status: complete.

### Phase 2: Producer zero-copy + copy path
- Slot claim/commit + offer_frame.
- Pool selection by size.
Status: complete.

### Phase 3: Tests + tooling
- Integration tests against Julia driver.
- Example C producer/consumer programs.
Status: in progress (CMake + example program added; unit test for superblock validation added; integration tests pending).

Optional features (deferred from v1):
- QoS monitor.
- Metadata cache.
- Discovery client.

## 9. Open Questions (to resolve before coding)
- How much of Aeron C client to vendor vs depend on? Prefer vendoring only the minimal required pieces.
Status: vendored Aeron C client sources under `c/vendor/aeron` with CMake build.

## 10. References
- Aeron C client layout: `/home/dgamroth/workspaces/codex/aeron/aeron-client/src/main/c`
- Specs: `docs/SHM_Tensor_Pool_Wire_Spec_v1.1.md`, `docs/SHM_Driver_Model_Spec_v1.0.md`
