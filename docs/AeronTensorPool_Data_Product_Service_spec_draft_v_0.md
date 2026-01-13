# AeronTensorPool Data Product Service Specification (Draft v0.1, RFC Style)

## 1. Scope

This document defines a standalone data product service that consumes datasets
produced by the AeronTensorPool Data Recorder and emits derived products (e.g.,
FITS). It is an offline or side-band service and MUST NOT impact recorder hot
path behavior.

It depends on `docs/AeronTensorPool_Data_Recorder_spec_draft_v_0.md` and
`docs/SHM_TraceLink_Spec_v1.0.md`.

## 2. Key Words

The key words "MUST", "MUST NOT", "REQUIRED", "SHOULD", "SHOULD NOT", and "MAY"
are to be interpreted as described in RFC 2119.

## 3. Conformance

Unless explicitly marked as Informative, sections in this document are
Normative.

## 4. Responsibilities

- Read recorded datasets (segments + SQLite manifest).
- Generate derived products (e.g., FITS) without modifying source data.
- Preserve provenance by linking products to trace IDs and source frames.

## 5. Inputs

- Recorder dataset root (manifest.sqlite + segments).
- Metadata events and TraceLink tables if present.
 
The product service MUST open the SQLite manifest in read-only mode and assume
WAL-enabled concurrent access by the recorder.

## 6. Outputs

- Derived products (e.g., FITS files, summary tables).
- Optional product manifest linking outputs to source frames and trace IDs.

## 7. Product Generation Rules

- Products MUST be reproducible from the recorded dataset.
- Products SHOULD include time ranges, stream IDs, and trace IDs used.
- Product generation SHOULD tolerate missing frames and record gaps explicitly.

## 8. FITS Products (Informative)

FITS generation MAY:

- Assemble headers from metadata events (DataSourceMeta) and TraceLink lineage.
- Generate cubes from frame ranges selected by time or sequence.
- Annotate FITS headers with `trace_id` and source stream identifiers.

### 8.1 FITS Header Mapping (Informative)

A compatible header mapping with the current ArchiverService.jl workflow is:

- `TIME-NS`: frame timestamp (nanoseconds).
- `AECORRID`: correlation or trace ID (if available).
- `AESCHMID`: SBE schemaId.
- `AETEMPID`: SBE templateId.
- `AEVERSON`: SBE version.
- `AERCTNS`: channel receive timestamp (if present).
- `AETXTNS`: channel send timestamp (if present).
- `AEURI`: Aeron URI (if available).
- `AESTREAM`: Aeron stream ID.

Implementations MAY add additional headers for dtype/shape/strides and data
source metadata.

### 8.2 FITS Cube Dimensioning (Informative)

When generating FITS cubes:

- The primary axis SHOULD be time-ordered frames.
- Additional axes SHOULD follow the tensor shape as recorded.
- If multiple streams are included, they SHOULD be separated into distinct HDUs
  or separate files unless explicitly requested.

## 9. Provenance

- Products SHOULD carry provenance references to `trace_id` and frame ranges.
- If TraceLink tables are available, products SHOULD include parent trace IDs
  or a reference to the lineage query used.

## 10. Open Questions (Informative)

## 11. Product Manifest (Informative)

Products MAY be indexed in a manifest table to enable reproducibility:

```sql
CREATE TABLE products (
  product_id   INTEGER PRIMARY KEY,
  product_type TEXT NOT NULL,
  path         TEXT NOT NULL,
  created_ns   INTEGER NOT NULL,
  stream_id    INTEGER,
  t_start_ns   INTEGER,
  t_end_ns     INTEGER,
  trace_id     INTEGER
);
```

- Product manifest schema.
- FITS header conventions for trace lineage.
- CLI/API surface for batch product generation.
