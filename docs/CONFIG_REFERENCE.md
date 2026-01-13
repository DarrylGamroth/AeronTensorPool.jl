# Configuration Reference

This document lists the configuration surfaces used by AeronTensorPool. The **driver** and **bridge** specs are authoritative. The producer/consumer/supervisor sections below are convenience configs used by examples and benchmarks.

Normative references:
- Driver config: `docs/SHM_Driver_Model_Spec_v1.0.md` (§16)
- Bridge config: `docs/SHM_Aeron_UDP_Bridge_Spec_v1.0.md` (§10)
 - Stream ID guidance: `docs/STREAM_ID_CONVENTIONS.md`

Examples:
- Driver: `docs/examples/driver_camera_example.toml`, `docs/examples/driver_integration_example.toml`
- Bridge: `docs/examples/bridge_config_example.toml`
- Example defaults (producer/consumer/supervisor): `config/defaults.toml`

---

## 1. Driver Configuration (authoritative)

Required keys (unless stated otherwise):

- `driver.instance_id` (string): identifier for logging/diagnostics. Default: `"driver-01"`.
- `driver.control_channel` (string): Aeron channel for control-plane messages. Default: `"aeron:ipc?term-length=4m"`.
- `driver.control_stream_id` (uint32): control-plane stream ID. Default: `1000`.
- `shm.base_dir` (string): root directory for SHM backing files. Default: `"/dev/shm/tensorpool"`.
- `profiles.*` (table): at least one profile must be defined.
- `profiles.<name>.payload_pools` (array): must contain at least one pool entry.
- `streams.*` (table): if `policies.allow_dynamic_streams=false`, each stream MUST be explicitly defined.

Optional keys and defaults:

- `driver.aeron_dir` (string): Aeron media driver directory. Default: Aeron library default.
- `driver.announce_channel` (string): channel for `ShmPoolAnnounce`. Default: `driver.control_channel`.
- `driver.announce_stream_id` (uint32): stream ID for `ShmPoolAnnounce`. Default: `driver.control_stream_id`.
- `driver.qos_channel` (string): channel for QoS messages. Default: `"aeron:ipc?term-length=4m"`.
- `driver.qos_stream_id` (uint32): QoS stream ID. Default: `1200`.
- `driver.stream_id_range` (string or array): inclusive range for dynamically created stream IDs (e.g., `"20000-29999"`). Default: empty (disabled).
- `driver.descriptor_stream_id_range` (string or array): inclusive range for per-consumer descriptor stream IDs. Default: empty (disabled).
- `driver.control_stream_id_range` (string or array): inclusive range for per-consumer control stream IDs. Default: empty (disabled).
- `shm.require_hugepages` (bool): default policy for hugepage-backed SHM when `requireHugepages=UNSPECIFIED`. Default: `false`.
- `shm.page_size_bytes` (uint32): backing page size for validation. Default: `4096`.
- `shm.permissions_mode` (string): POSIX mode for created files. Default: `"660"`.
- `shm.allowed_base_dirs` (array of string): allowlist for URIs. Default: `[shm.base_dir]`.
- `policies.allow_dynamic_streams` (bool): allow on-demand stream creation. Default: `false`.
- `policies.default_profile` (string): profile used for dynamic streams. Default: first defined profile.
- `policies.announce_period_ms` (uint32): `ShmPoolAnnounce` cadence. Default: `1000`.
- `policies.lease_keepalive_interval_ms` (uint32): client keepalive interval. Default: `1000`.
- `policies.lease_expiry_grace_intervals` (uint32): missed keepalives before expiry. Default: `3`.
- `policies.prefault_shm` (bool): prefault/zero SHM regions on create. Default: `true`.
- `policies.reuse_existing_shm` (bool): reuse existing SHM files without truncation. Default: `false`.
- `policies.mlock_shm` (bool): mlock SHM regions on create; fatal if enabled and mlock fails. Default: `false`.
- `policies.cleanup_shm_on_exit` (bool): remove SHM files on driver shutdown. Default: `false`.
- `policies.epoch_gc_enabled` (bool): enable epoch directory GC. Default: `true`.
- `policies.epoch_gc_keep` (uint32): number of epochs to keep (current + N-1). Default: `2`.
- `policies.epoch_gc_min_age_ns` (uint64): minimum age before deletion. Default: `3 × announce_period`.
- `policies.epoch_gc_on_startup` (bool): run GC at driver startup. Default: `false`.
- `policies.shutdown_timeout_ms` (uint32): drain period before shutdown completes. Default: `2000`.
- `policies.shutdown_token` (string): admin shutdown token. Default: empty (disabled).

Profile fields:

- `profiles.<name>.header_nslots` (uint32): power-of-two slot count. Default: `1024`.
- `profiles.<name>.payload_pools[].pool_id` (uint16): pool identifier (unique per profile).
- `profiles.<name>.payload_pools[].stride_bytes` (uint32): payload slot size in bytes (offset = `slot_index * stride_bytes`).

Stream fields:

- `streams.<name>.stream_id` (uint32): stream identifier.
- `streams.<name>.profile` (string): profile name.

Environment overrides:
- Drivers SHOULD accept `ENV` overrides using Aeron’s convention: uppercase the key and replace `.` with `_` (e.g., `driver.control_stream_id` -> `DRIVER_CONTROL_STREAM_ID`).

Example profile with four pool sizes:

```toml
[profiles.camera]
header_nslots = 256
payload_pools = [
  { pool_id = 1, stride_bytes = 65536 },
  { pool_id = 2, stride_bytes = 262144 },
  { pool_id = 3, stride_bytes = 1048576 },
  { pool_id = 4, stride_bytes = 4194304 }
]
```

---

## 2. Bridge Configuration (authoritative)

Required keys:

- `bridge.instance_id` (string): identifier for logging/diagnostics.
- `bridge.payload_channel` (string): Aeron UDP channel for `BridgeFrameChunk`.
- `bridge.payload_stream_id` (uint32): stream ID for `BridgeFrameChunk`.
- `bridge.control_channel` (string): Aeron channel for control messages (forwarded `ShmPoolAnnounce`, and when enabled, `Qos*` and `FrameProgress`).
- `bridge.control_stream_id` (uint32): stream ID for bridge control messages.
- `mappings` (array): one or more stream mappings.

Optional keys and defaults:

- `bridge.mtu_bytes` (uint32): MTU used to size chunks. Default: Aeron channel MTU.
- `bridge.chunk_bytes` (uint32): payload bytes per chunk. Default: `bridge.mtu_bytes - 128`.
- `bridge.max_chunk_bytes` (uint32): hard cap for chunk length. Default: `65535`.
- `bridge.max_payload_bytes` (uint32): hard cap for payload length. Default: `1073741824`.
- `bridge.dest_stream_id_range` (string or array): inclusive range for dynamically allocated destination stream IDs. Default: empty (disabled).
- `bridge.forward_metadata` (bool): forward `DataSourceAnnounce`/`DataSourceMeta`. Default: `true`.
- `bridge.metadata_channel` (string): Aeron UDP channel for metadata forwarding. Default: empty (disabled unless set).
- `bridge.metadata_stream_id` (uint32): stream ID for forwarded metadata. Default: deployment-specific.
- `bridge.source_metadata_stream_id` (uint32): source metadata stream ID to subscribe on the sender host. Default: deployment-specific.
- `bridge.forward_qos` (bool): forward QoS messages. Default: `false`.
- `bridge.forward_progress` (bool): forward `FrameProgress`. Default: `false`.
- `bridge.assembly_timeout_ms` (uint32): per-stream frame assembly timeout. Default: `250`.

Mapping fields:

- `mappings[].source_stream_id` (uint32): stream ID consumed from local SHM.
- `mappings[].dest_stream_id` (uint32): stream ID produced on the destination host.
- `mappings[].profile` (string): destination profile name or pool mapping policy.
- `mappings[].metadata_stream_id` (uint32, optional): destination metadata stream ID. Default: `dest_stream_id`.
- `mappings[].source_control_stream_id` (uint32, optional): source control stream ID for progress/QoS. Default: `0` (disabled).
- `mappings[].dest_control_stream_id` (uint32, optional): destination control stream ID for progress/QoS. Default: `0` (disabled).

---

## 3. Example Producer/Consumer/Supervisor Config (non-authoritative)

These keys are used by example scripts and benchmarks (`config/defaults.toml`). In driver mode, clients typically connect via API rather than TOML, but these settings remain useful for local testing.

### Producer

`[producer]`:
- `aeron_dir`, `aeron_uri`
- `descriptor_stream_id`, `control_stream_id`, `qos_stream_id`, `metadata_stream_id`
- `stream_id`, `producer_id`, `layout_version`, `nslots`
- `shm_base_dir`, `shm_namespace`, `header_uri`
- `announce_interval_ns`, `qos_interval_ns`
- `progress_interval_ns`, `progress_bytes_delta`

`[[producer.payload_pools]]`:
- `pool_id`, `uri`, `stride_bytes`, `nslots`

### Consumer

`[consumer]`:
- `aeron_dir`, `aeron_uri`
- `descriptor_stream_id`, `control_stream_id`, `qos_stream_id`
- `stream_id`, `consumer_id`, `expected_layout_version`
- `mode`, `max_outstanding_seq_gap`
- `use_shm`, `supports_shm`, `supports_progress`
- `max_rate_hz`
- `payload_fallback_uri`
- `shm_base_dir`, `require_hugepages`
- `progress_interval_us`, `progress_bytes_delta`, `progress_major_delta_units`
- `hello_interval_ns`, `qos_interval_ns`

### Supervisor

`[supervisor]`:
- `aeron_dir`, `aeron_uri`
- `control_stream_id`, `qos_stream_id`
- `stream_id`
- `liveness_timeout_ns`, `liveness_check_interval_ns`

---

## 4. Notes

- Driver and bridge configs are normative for production deployments.
- Client configs are convenience tooling; applications can supply parameters via API instead.
- `config/defaults.toml` is intended for local tests/benchmarks and may not match production sizing.
