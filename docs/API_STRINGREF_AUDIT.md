# StringRef Usage Audit

## Summary
StringRef-backed fields are used only in driver response views. Public call sites should use `materialize(poller)` to obtain owned strings. The StringRef helpers remain internal (not exported).

## Types with StringRef Fields
- `DriverPoolInfo.region_uri`
- `AttachResponseInfo.header_region_uri`
- `AttachResponseInfo.error_message`
- `DetachResponseInfo.error_message`
- `LeaseRevokedInfo.error_message`
- `DriverShutdownInfo.error_message`

## Call Sites Using Materialize
- `src/agents/consumer/logic.jl`
  - `handle_driver_events!` uses `materialize(poller).attach`.
- `src/agents/producer/logic.jl`
  - `handle_driver_events!` uses `materialize(poller).attach`.
- `src/client/driver_client.jl`
  - `driver_client_do_work!` uses `materialize(poller)` for revoke/shutdown.
  - `poll_attach!` uses `materialize(poller).attach`.
- Tests:
  - `test/test_driver_attach.jl`
  - `test/test_driver_shutdown.jl`
  - `test/test_driver_shutdown_request.jl`
  - `test/test_driver_lease_expiry.jl`
  - `test/test_driver_shutdown_timer.jl`
  - `test/test_driver_integration.jl`
  - `test/test_driver_reattach.jl`
  - `test/test_full_stack_driver_mode.jl`

## Notes
- `DriverResponsePoller` stores StringRef values in an arena buffer; views become invalid after arena wrap.
- `map_from_attach_response!` now accepts owned `AttachResponseInfo` values (materialize before mapping).
