# SHM Service Control Plane Specification (v1.0, RFC Style)

## 1. Scope

This document defines the shared control/status streams used to manage services
(blocks) in the AeronTensorPool ecosystem. It specifies EventMessage transport
and consumer-side filtering. It is independent of the data plane and does not
grant SHM attachment authority.

## 2. Key Words

The key words "MUST", "MUST NOT", "REQUIRED", "SHOULD", "SHOULD NOT", and "MAY"
are to be interpreted as described in RFC 2119.

## 3. Conformance

Unless explicitly marked as Informative, sections in this document are
Normative.

## 4. Streams and Roles

- Control stream: shared EventMessage stream carrying commands to services.
- Status stream: shared EventMessage stream carrying accepted commands and
  service status.
- Services MUST subscribe to the control stream and MAY publish to the status
  stream.

## 5. EventMessage Transport

- EventMessages MUST be SBE encoded and carried on Aeron streams using standard
  Aeron messaging (IPC/UDP as configured).
- Mixed-schema traffic MUST be guarded by `MessageHeader.schemaId`.
- Services MUST filter EventMessages by `tag` (service identifier) and MUST
  ignore non-target messages without allocating.

### 5.1 EventMessage Schema (Informative)

A representative EventMessage schema is shown below. Implementations MAY use a
compatible schema with additional fields as needed.

```xml
<types>
  <enum name="Format" encodingType="int8">
    <validValue name="NOTHING">0</validValue>
    <validValue name="UINT8">1</validValue>
    <validValue name="INT8">2</validValue>
    <validValue name="UINT16">3</validValue>
    <validValue name="INT16">4</validValue>
    <validValue name="UINT32">5</validValue>
    <validValue name="INT32">6</validValue>
    <validValue name="UINT64">7</validValue>
    <validValue name="INT64">8</validValue>
    <validValue name="FLOAT32">9</validValue>
    <validValue name="FLOAT64">10</validValue>
    <validValue name="BOOLEAN">11</validValue>
    <validValue name="STRING">12</validValue>
    <validValue name="BYTES">13</validValue>
    <validValue name="BIT">14</validValue>
    <validValue name="REF">15</validValue>
  </enum>
</types>

<sbe:message name="EventMessage" id="1">
  <field name="timestampNs" id="1" type="int64"/>
  <field name="correlationId" id="2" type="int64"/>
  <field name="format" id="3" type="Format"/>
  <field name="pad" id="4" type="uint8" length="3"/>
  <field name="refStreamId" id="5" type="uint32" presence="optional" nullValue="4294967295"/>
  <field name="refEpoch" id="6" type="uint64" presence="optional" nullValue="18446744073709551615"/>
  <field name="refSeq" id="7" type="uint64" presence="optional" nullValue="18446744073709551615"/>
  <data  name="tag" id="10" type="varAsciiEncoding"/>
  <data  name="key" id="11" type="varAsciiEncoding"/>
  <data  name="value" id="20" type="varDataEncoding"/>
</sbe:message>
```

### 5.2 REF and TraceLink Support (Informative)

- If `format=REF`, the message SHOULD populate `refStreamId`, `refEpoch`, and
  `refSeq`. The `value` blob MUST NOT redundantly encode the reference tuple.
- Implementations MAY treat `value` length == 0 as an implicit REF, in which
  case `refStreamId/refEpoch/refSeq` MUST be populated.
- EventMessages MAY carry `trace_id` in place of, or alongside, `correlationId`.
  Implementations SHOULD preserve whichever identity field is present.

## 6. Status Echo

- Accepted commands MUST be echoed onto the shared status stream.
- The status stream is the authoritative record of accepted commands.

## 7. Open Questions (Informative)

## 7. Tag Naming (Informative)

Services SHOULD use a stable tag naming convention for routing. Recommended
format:

- `service:<name>` for primary services (e.g., `service:recorder`).
- `service:<name>:<instance>` for multi-instance deployments.
