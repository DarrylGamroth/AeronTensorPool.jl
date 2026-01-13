# Alternatives and Tradeoffs

This document summarizes alternative shared-memory frameworks and discovery
options for the AeronTensorPool design. It focuses on the zero-allocation hot
path requirement.

## Requirements Summary

- Zero-allocation hot path (data plane).
- Control plane and discovery can allocate (not hot path).
- Aeron and SBE are optional if they do not satisfy the above.

## Shared-Memory Framework Alternatives

### Iceoryx

Pros:
- Designed for zero-copy SHM transport.
- Mature and widely used in low-latency systems.

Cons:
- Opinionated runtime and API model.
- Still requires custom logic for seqlock/epoch semantics and tensor header
  layout if you want exact behavior.

Fit:
- Best off-the-shelf candidate if Aeron/SBE are not required.

### eCAL

Pros:
- Strong tooling and operational UX.
- SHM transport available.

Cons:
- Less direct control over exact SHM layout and header semantics.
- Zero-allocation hot path is not guaranteed for custom layouts.

Fit:
- Good for tooling-driven deployments, weaker for strict hot-path guarantees.

### DDS with SHM (Cyclone DDS / Connext)

Pros:
- Standardized APIs and broad ecosystem.
- Built-in discovery and QoS.

Cons:
- Larger stack, more abstraction overhead.
- Zero-allocation hot path can be difficult to guarantee end-to-end.

Fit:
- Best for ecosystem integration, not for strict hot-path constraints.

### ROS 2 with SHM

Pros:
- Strong robotics ecosystem.
- SHM transport options exist (e.g., rmw_iceoryx).

Cons:
- ROS message model and tooling overhead.
- Not ideal for minimal or standalone deployments.

Fit:
- Great for ROS-based systems, overkill otherwise.

### Low-Level SHM (mmap + POD headers)

Pros:
- Maximum control over layout, seqlock semantics, and hot-path allocations.
- Minimal dependencies.

Cons:
- Requires more custom control-plane and discovery work.

Fit:
- Closest to current design goals.

## Control Plane Alternatives (Non-Hot Path)

### JSON/HTTP

Pros:
- Simple, ubiquitous.
- Easy to integrate with existing services.

Cons:
- Allocations unavoidable, but acceptable if not hot path.

Fit:
- Good minimal control plane if Aeron is not required.

### gRPC + Protobuf

Pros:
- Strong tooling and compatibility.
- Widely adopted.

Cons:
- Julia implementations are not zero-allocation; disqualified for hot path.

Fit:
- Acceptable only if used strictly off the hot path and allocation is OK.

## Discovery and Registry Options

### Consul

Pros:
- Service registry with health checks and TTLs.
- Good multi-host support.

Cons:
- Heavier operational footprint than lightweight options.

Fit:
- Good for larger deployments.

### etcd

Pros:
- Strong watch semantics.
- Minimal API surface.

Cons:
- Still a separate service to operate.

Fit:
- Good when strong consistency is required.

### ZooKeeper

Pros:
- Ephemeral nodes map well to liveness.

Cons:
- Operationally heavier than simple alternatives.

Fit:
- Works for large fleets with existing ZooKeeper infra.

### Kubernetes API

Pros:
- No extra services if already on K8s.
- Services and Endpoints provide discovery.

Cons:
- Tied to Kubernetes.

Fit:
- Best for K8s-native deployments.

### mDNS/DNS-SD

Pros:
- Very lightweight, zero extra services.
- Good for single-LAN discovery.

Cons:
- Limited scope and control.

Fit:
- Good for local or lab environments.

### File-Based Registry

Pros:
- Minimal dependencies.
- Easy to implement and debug.

Cons:
- Requires careful locking/atomic updates.

Fit:
- Good for single-host or tightly controlled multi-host setups.

### UDP Multicast Beacons

Pros:
- Very lightweight, easy to implement.
- No persistent service required.

Cons:
- Best-effort delivery; must handle drops.

Fit:
- Good for low-friction discovery when reliability is not strict.

## Recommended Path if Aeron/SBE Are Optional

- Keep SHM + POD header + seqlock for the data plane (zero-alloc hot path).
- Use a simple control-plane protocol (JSON/HTTP) if allocations are acceptable.
- Use a lightweight discovery approach (file-based registry or UDP beacons).

If stronger discovery semantics are needed, use Consul or etcd and keep the
control plane thin.
