# Per-Consumer Stream Requests (Client API)

Clients normally stay on shared descriptor/control streams. When a consumer needs dedicated
streams (e.g., isolated descriptors for UI throttling or per-consumer progress), request them
via the consumer settings passed to the API. There is no client TOML; this is an API-level
option only.

```julia
consumer_cfg = ConsumerSettings(
    aeron_dir,
    "aeron:ipc?term-length=4m",
    Int32(1100),  # shared descriptor stream
    Int32(1000),  # shared control stream
    Int32(1200),  # qos stream
    UInt32(1),    # stream_id
    UInt32(42),   # consumer_id
    UInt32(1),    # expected_layout_version
    UInt8(MAX_DIMS),
    Mode.STREAM,
    UInt16(1),
    UInt32(256),
    true,
    true,
    true,
    UInt16(30),   # max_rate_hz applies only to per-consumer descriptors
    "",
    "",
    String[],
    false,
    UInt32(250),
    UInt32(65536),
    UInt32(0),
    UInt64(1_000_000_000),
    UInt64(1_000_000_000),
    UInt64(3_000_000_000),
    "aeron:ipc?term-length=4m",
    UInt32(2300), # requested per-consumer descriptor stream
    "aeron:ipc?term-length=4m",
    UInt32(2301), # requested per-consumer control (progress) stream
    false,
)
```

If the producer declines, it returns empty channel and zero/null stream IDs in `ConsumerConfig`,
and the consumer stays on the shared streams.
