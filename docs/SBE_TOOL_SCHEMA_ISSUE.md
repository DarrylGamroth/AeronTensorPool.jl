# SBE.jl Issue Report: Schema Compatibility with Java sbe-tool

## Summary
Our wire/driver schemas are accepted by SBE.jl, but the Java `sbe-tool` rejects them due to two validation rules. This makes it hard to generate C codecs from the same schema.

## Problem Cases
1) **Optional varAscii/varData fields**
   - The schema uses `presence="optional"` on `varAsciiEncoding` (and varData).
   - Java `sbe-tool` rejects optional varData/varAscii fields.

2) **Enum nullValue clashes with a defined constant**
   - The schema has an enum with `nullValue="0"` and also defines `UNKNOWN = 0`.
   - Java `sbe-tool` rejects enums where `nullValue` equals a defined constant value.

## Expected Behavior (SBE.jl)
SBE.jl should either:
- Validate and reject schemas that violate sbe-tool rules (to keep cross-codegen compatibility), or
- Provide a compatibility option to rewrite or warn (e.g., strip `presence="optional"` from varAscii/varData, or require `UNKNOWN` to be the nullValue but not a defined constant).

## Reproduction
Use the minimal schema below and run the Java sbe-tool:

```
java -cp sbe-tool.jar:agrona.jar uk.co.real_logic.sbe.SbeTool \
  --targetLanguage C \
  --outputDir gen \
  docs/sbe_schema_repro.xml
```

### Minimal schema
See `docs/sbe_schema_repro.xml`.

## Notes / Proposed Fixes
- For optional varAscii/varData, use empty string/zero-length as the “null” value instead of presence optional.
- For enums, move UNKNOWN to the nullValue only (do not define it as a normal constant), or pick a distinct nullValue (e.g., 255) not used by any constant.
