# SBE Tool Compatibility Plan

Goal: ensure the spec schemas and prose are accepted by the Java `sbe-tool` without hand-editing for C codegen.

## Scope
- `schemas/wire-schema.xml`
- `schemas/driver-schema.xml`
- Relevant spec prose:
  - `docs/SHM_Tensor_Pool_Wire_Spec_v1.1.md`
  - `docs/SHM_Driver_Model_Spec_v1.0.md`

## Compatibility Rules (sbe-tool constraints)
1) **No `presence="optional"` on varAscii/varData fields.**
   - Replace with empty string / zero-length semantics.
   - Update prose to define “absent” as length=0.
2) **Enum `nullValue` must not equal any defined constant.**
   - Move “UNKNOWN” into nullValue only (remove explicit `UNKNOWN=0`), or
   - Use a distinct nullValue (e.g., 255) not used by any constant.

## Phase 1: Schema edits
1. **Driver schema**
   - Remove `presence="optional"` from any varAscii/varData fields.
   - Update enums with conflicting `nullValue`:
     - `PublishMode` (and any similar enums) to avoid `UNKNOWN=0` if `nullValue=0`.
2. **Wire schema**
   - Remove `presence="optional"` from varAscii/varData fields (if present).
   - Ensure enums do not define `UNKNOWN` equal to `nullValue`.

## Phase 2: Prose updates
1. **Driver spec prose**
   - Define “optional string” fields as length=0 indicates unset.
   - Update enum definitions to match schema changes (no explicit UNKNOWN=0 if nullValue=0).
2. **Wire spec prose**
   - Same treatment for optional varAscii/varData.
   - Note sbe-tool compatibility requirement in a short “Schema Compatibility” subsection.

## Phase 3: Regenerate codecs
1. Regenerate SBE outputs for Julia (`src/gen`) and C (`c/gen`).
2. Verify schema IDs, block lengths, template IDs unchanged except where intended.

## Phase 4: Validation
1. Run Java `sbe-tool` against updated schemas.
2. Run existing unit tests for schema-dependent code (Julia + C).

## Deliverables
- Updated `schemas/*.xml`
- Updated spec prose in `docs/*.md`
- Regenerated SBE outputs
- Short note in docs that schemas are sbe-tool compliant

Status: complete.
