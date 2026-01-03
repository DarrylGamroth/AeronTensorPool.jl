# StringRef Usage Audit

## Summary
StringRef-backed fields are used only in driver response snapshots. Callers must use `string_ref_view` or `string_ref_string` to access values. The helpers are currently internal (not exported).

## Types with StringRef Fields
- `DriverPoolInfo.region_uri`
- `AttachResponseInfo.header_region_uri`
- `AttachResponseInfo.error_message`
- `DetachResponseInfo.error_message`
- `LeaseRevokedInfo.error_message`
- `DriverShutdownInfo.error_message`

## Call Sites Using StringRef Helpers
- `src/agents/consumer/mapping.jl`
  - `map_from_attach_response!` uses `string_ref_view` for `header_region_uri` and `pool.region_uri`.
- `src/agents/producer/logic.jl`
  - `producer_config_from_attach` uses `string_ref_string` for `header_region_uri` and `pool.region_uri`.
- `test/test_driver_attach.jl`
  - Uses `string_ref_view` to assert `header_region_uri`.
- `test/test_driver_shutdown.jl`
  - Uses `string_ref_view` for shutdown `error_message`.
- `test/test_driver_shutdown_request.jl`
  - Uses `string_ref_view` for shutdown `error_message`.

## Notes
- `DriverResponsePoller` stores StringRef values in an arena buffer; views become invalid after arena wrap.
- `map_from_attach_response!` currently accepts `AttachResponseInfo` (StringRef-backed) and must run before any arena overwrite. Decision log requires materialization before mapping in Phase 2a.

