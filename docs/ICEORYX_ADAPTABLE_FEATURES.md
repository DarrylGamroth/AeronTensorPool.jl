# Iceoryx Features That Map to AeronTensorPool

This note summarizes Iceoryx/Iceoryx2 features that can be adapted to
AeronTensorPool without changing the zero-allocation hot path.

## 1) Blackboard (Latest-Value Store)

Iceoryx2 provides a "blackboard" pattern for sharing the latest state.

Adaptation for AeronTensorPool:
- Use a dedicated stream or a single-slot header ring.
- Always write to the same slot; consumers read the latest committed header.
- Reuse existing seqlock semantics; no backpressure needed.

## 2) Event Signaling

Iceoryx2 exposes events as a signaling pattern.

Adaptation:
- Define a lightweight control-plane message (e.g., `ServiceEvent`) on a
  dedicated control/QoS stream.
- Keep it out of the data-plane hot path.

## 3) Request/Response

Iceoryx2 supports request/response via loaned samples.

Adaptation:
- Add request/response message types to the control plane (SBE).
- Use the driver or supervisor as a reply authority.
- Keep responses small and off the hot path.

## 4) Introspection and Health Monitoring

Iceoryx provides introspection tooling for ports and memory usage.

Adaptation:
- Define an introspection stream with fixed SBE messages (counters, lease
  state, QoS summaries).
- Reuse existing counter infrastructure; avoid data-plane changes.

## 5) User-Header Concept (Optional, v2-level)

Iceoryx allows a user header before the payload.

Adaptation:
- Consider a versioned optional header extension in `headerBytes`.
- Maintain a fixed v1.1 layout; introduce extensions only with a new
  `layout_version`.

## 6) QoS Vocabulary

Iceoryx uses explicit QoS policies (block/drop/history).

Adaptation:
- Reuse terminology for documentation and tooling.
- Preserve ATP’s lossy overwrite semantics as the default.
