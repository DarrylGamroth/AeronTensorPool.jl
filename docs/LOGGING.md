# Logging

AeronTensorPool uses lightweight compile-time logging macros defined in `src/core/logging.jl`.

## Enable/disable

Set the following environment variables before starting a process:

- `TP_LOG=1` to enable logging (default off).
- `TP_LOG_LEVEL` as an integer:
  - `10` = debug
  - `20` = info
  - `30` = warn
  - `40` = error
- `TP_LOG_MODULES` as a comma-separated list of module names to include (default: all).

Example:
```bash
TP_LOG=1 TP_LOG_LEVEL=20 julia --project scripts/example_producer.jl
TP_LOG=1 TP_LOG_LEVEL=20 TP_LOG_MODULES=Producer,Driver julia --project scripts/example_producer.jl
```

## Macros

- `@tp_debug`
- `@tp_info`
- `@tp_warn`
- `@tp_error`

These are no-ops when logging is disabled, so they are safe to leave in hot paths.
