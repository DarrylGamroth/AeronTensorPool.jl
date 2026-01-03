# FixedString Usage Audit

## Summary
Fixed-size string buffers are used in driver response snapshots to avoid arena lifetimes and per-poll string allocation. Call sites use `view(fs)` for zero-copy access or `String(fs)` when an owned `String` is required.

## Types with FixedString Fields
- `DriverPool.region_uri`
- `AttachResponse.header_region_uri`
- `AttachResponse.error_message`
- `DetachResponse.error_message`
- `LeaseRevoked.error_message`
- `DriverShutdown.error_message`

## Call Sites Using FixedString Accessors
- `src/agents/consumer/mapping.jl`
  - `map_from_attach_response!` uses `view`.
- `src/agents/producer/logic.jl`
  - `producer_config_from_attach` uses `String`.
- Tests read `view`/`String` where needed.

## Notes
- Driver response snapshots are safe to keep; there is no arena reuse.
