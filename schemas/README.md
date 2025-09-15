# Schemas: Source- and Event-Driven Log Types

This folder contains YAML schemas that declaratively define each log source and its events. A generator turns these schemas into Sorbet-typed Ruby `T::Struct`s under `lib/log_struct/log/*`, plus supporting helpers.

## How It Works

- **Inputs:** YAML files in `schemas/log_sources/*.yml` and the meta JSON Schemas in `schemas/meta/*`.
- **Enums:** Human-friendly field names are defined in `lib/log_struct/enums/log_field.rb` (e.g., `Database`, `DurationMs`). Each enum value serializes to a compact JSON key (e.g., `:db`, `:duration_ms`).
- **Validation:** The meta schema `schemas/meta/log-source-schema.json` validates every source schema. It imports `schemas/meta/log-fields.json`, an auto-generated enum of allowed `LogField` names for field keys.
- **Codegen:** Run `ruby scripts/generate_structs.rb` to:
  - Generate Ruby structs for every source/event
  - Rebuild `schemas/meta/log-fields.json` from `LogField` so schema validation stays in sync

## Files and Responsibilities

- **schemas/log_sources/\*.yml:** One file per source. Declares base fields and events.
- **schemas/meta/log-source-schema.json:** JSON Schema for validating the shape and field names of all source YAMLs.
- **schemas/meta/log-fields.json:** Generated from `LogField`; lists the only allowed field key names.
- **scripts/generate_structs.rb:** Main codegen entry; generates Ruby + TS and log-fields.
- LogField meta schema is generated as part of `scripts/generate_structs.rb` (from the `LogField` enum).

## Schema Format

- **source:** Required. CamelCase source name, e.g., `ActiveJob`, `SQL`.
- **snake_case:** Optional snake-case filename override; normally inferred.
- **consts.source:** Optional override for the `Source` enum; omit unless it differs from source name.
- **additional_data:** Boolean. If true, generated structs include an `additional_data` Hash merged at top-level on serialization.
- **add_request_fields:** Boolean. Adds request-related accessors and merges them during serialization.

### Base Fields

- Preferred form:
- **base.optional:** Optional boolean. When true, base fields are optional by default; use per-field `required: true` to force required. When omitted/false, fields are required by default.
  - **base.fields:** Map of `LogField` names to types.
- Legacy form:
  - `base_fields:` is still supported (treated as optional-by-default). Prefer `base:` going forward.

### Events

- **events:** Map of event name → object with keys:
  - **optional:** Optional boolean. When true, fields are optional by default; use per-field `required: true` to force required. When omitted/false, fields are required by default.
  - **fields:** Map of `LogField` names to types. Field keys must be valid `LogField` enum names (validated by `log-fields.json`).

- You may also declare an event with no fields by using a bare event key or `null`:
  - `Delivery:` or `Delivery: null` → generates an event with no additional fields.

### Field Declarations

You can write fields in two styles:

- **Shorthand (recommended):** `FieldName: Type`
  - Required determined by `default_required` (event/base).
  - Example: `DurationMs: Float`

- **Object form (conditional required):**
  - `FieldName:
type: Type
required: false`
  - Use when some fields must remain optional even if `default_required: true`.

### Naming Rules

- Use the exact `LogField` constant name for keys (e.g., `RequestId`, `Database`, `DurationMs`, `WaitMs`).
- The generator maps these to short JSON keys via `LogField` (e.g., `RequestId` → `:request_id`).

## Units and Conventions

- **Durations:** Prefer explicit units. Use `DurationMs` for durations in milliseconds. Use `WaitMs` for wait times in milliseconds.
- **Optional data:** Use `additional_data: true` only when needed; the generator flattens the hash on serialization.
- **Source override:** Omit `consts.source` unless the source enum differs from the source name.

## Codegen Outputs

- Single-event sources generate a single top-level struct (e.g., `LogStruct::Log::Request`).
- Multi-event sources generate:
  - A parent file `lib/log_struct/log/<source>.rb` that requires event files and may define `BaseFields`.
  - One file per event (e.g., `lib/log_struct/log/<source>/<event>.rb`).
- All generated classes:
  - Include shared common fields (source, event, timestamp, level)
  - Serialize using `LogField::<Name>.serialize` for every key
  - Serialize `Time` fields as ISO-8601 strings
  - Respect `default_required` and `required` for field nilability

## When To Use `optional`

- Use `default_required: false` when all fields in an event (or base) are optional — this removes per-field `required: false` noise.
- Do NOT add `default_required: false` when you have a mix of required and optional fields — declare required fields in shorthand and optional fields with `required: false`.

Examples:

- All optional fields:
  - `default_required: false`
  - `fields:
Filename: String
MimeType: String`

- Mixed required/optional fields:
  - Omit `optional`
  - `fields:
Message: String
AhoyEvent:
  type: String
  required: false`

## Validating and Generating

- **Validate schemas:** `bundle exec ruby -Itest test/schemas/schema_validation_test.rb`
- **Generate structs + log-fields:** `ruby scripts/generate_structs.rb`

## Common Pitfalls

- Using snake_case field keys. Always use `LogField` names (e.g., `RequestId`, not `request_id`).
- Adding `default_required: false` to events that have a mix of required and optional fields — this turns everything optional. Instead, omit it and mark optional fields explicitly.
- Hardcoding JSON keys. Generated code always uses `LogField::<Name>.serialize` for keys.
