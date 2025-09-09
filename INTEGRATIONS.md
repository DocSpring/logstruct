**Purpose**

- Document how to add a new first‑class integration to LogStruct so it’s consistent, type‑safe, well‑tested, and shows up automatically in the docs site with an auto‑generated example log.

**High‑Level Flow**

- Add a typed log structure under `lib/log_struct/log/` (so the docs generator picks it up).
- Add a configuration toggle in `ConfigStruct::Integrations` and wire it into `Integrations.setup_integrations`.
- Implement the integration under `lib/log_struct/integrations/…` to produce that log type.
- Add the dev dependency for the third‑party gem and generate RBIs with Tapioca.
- Add tests (unit + behavior) under `test/log_struct/integrations` and (if needed) `test/log_struct/log`.
- Add a short entry in the docs metadata (`site/lib/integration-helpers.ts`). The Integrations page will render it automatically via `AllLogTypes`.
- Run type export to update the docs’ TypeScript types.

**Conventions**

- Files and naming:
  - Log type: `lib/log_struct/log/<Name>.rb` (class `LogStruct::Log::<Name>`)
  - Integration: `lib/log_struct/integrations/<name>.rb` (module `LogStruct::Integrations::<Name>`)
  - Optional submodules (e.g., `logger.rb`, `log_subscriber.rb`) live below a folder `lib/log_struct/integrations/<name>/`.
  - Tests mirror structure under `test/log_struct/log` and `test/log_struct/integrations`.
- Type safety:
  - Every Ruby file must be `# typed: strict` and use `T::Sig`.
  - For integration setup signatures: `sig { params(config: LogStruct::Configuration).returns(T.nilable(TrueClass)) }`.
  - Prefer real constants (the gem is a development dependency), but guard runtime with `defined?(::GemModule)` to be safe in user apps.
- Error handling:
  - Never raise from the integration path; use `LogStruct.handle_exception(error, source: <Source>, context: {integration: :name})`.
- Logging:
  - Produce a dedicated typed log struct (do NOT emit a generic/plain log).
  - Message naming: concise and stable, e.g., `"ams.render"`, `"ahoy.track"`.
  - Choose the correct `Source` (Rails/App/Job/Storage/…) and a suitable `Event` (`Event::Log` unless a more specific event applies).

**Step‑by‑Step Checklist**

1. Create the typed log struct
   - File: `lib/log_struct/log/<name>.rb`
   - Include: `Interfaces::CommonFields`, `Interfaces::AdditionalDataField`, `SerializeCommon`, `MergeAdditionalDataFields`.
   - Define required fields and defaults (e.g., `message`, specific properties for the integration), and implement `serialize` to add them to the output.
   - Example skeleton:

     class LogStruct::Log::Example < T::Struct
     extend T::Sig
     include Interfaces::CommonFields
     include Interfaces::AdditionalDataField
     include SerializeCommon
     include MergeAdditionalDataFields

     ExampleEvent = T.type_alias { Event::Log }
     const :source, Source::Rails, default: T.let(Source::Rails, Source::Rails)
     const :event, ExampleEvent, default: T.let(Event::Log, ExampleEvent)
     const :level, Level, default: T.let(Level::Info, Level)
     const :timestamp, Time, factory: -> { Time.now }

     const :message, String, default: "example.event"
     const :detail, T.nilable(String), default: nil
     const :additional_data, T::Hash[Symbol, T.untyped], default: {}

     sig { override.params(strict: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
     def serialize(strict = true)
     h = serialize_common(strict)
     merge_additional_data_fields(h)
     h[LOG_KEYS.fetch(:message)] = message
     h[:detail] = detail if detail
     h
     end
     end

2. Register the log type
   - In `lib/log_struct/log.rb`:
     - `require_relative "log/<name>"`

3. Add a config toggle
   - In `lib/log_struct/config_struct/integrations.rb`:
     - `prop :enable_<name>, T::Boolean, default: true`
   - In `lib/log_struct/integrations.rb`:
     - `require_relative "integrations/<name>"`
     - Call `Integrations::<Name>.setup(config)` inside `setup_integrations` behind the toggle.

4. Implement the integration
   - File: `lib/log_struct/integrations/<name>.rb`
   - Guard on presence of the third‑party gem (`return nil unless defined?(::ThirdParty)`), subscribe/hook into events, build your typed log, and log it with `LogStruct.info(log)`.
   - Use `handle_exception` on rescue.

5. Add development dependency + RBIs
   - In `logstruct.gemspec`, add the gem as a development dependency with a supported version:
     - `spec.add_development_dependency "third_party_gem", "~> X.Y"`
   - Run:
     - `bundle install`
     - `bundle exec tapioca gems` (commits RBIs under `sorbet/rbi/gems/...`).

6. Tests
   - Unit/behavior tests under `test/log_struct/integrations/<name>_test.rb`.
   - If the integration exposes a new log struct surface, add a focused test in `test/log_struct/log/<name>_test.rb` when it adds non‑trivial serialization.
   - Prefer real gem objects with small fakes only where necessary; the gem is available as a dev dependency.
   - Assertions should inspect `as_json` and verify:
     - `src`, `evt`, `lvl`, `ts` exist
     - `msg` matches the agreed name
     - Integration‑specific fields are present and correct

7. Docs
   - No custom sections in the Integrations page.
   - The Integrations page lists all `AllLogTypes` with titles/descriptions from `site/lib/integration-helpers.ts`.
   - Add an entry to `getLogTypeInfo` for your new log type (title, concise description, optional `configuration_code: 'integrations_configuration'`).
   - Run the type export to regenerate the docs’ TypeScript assets so example logs render:
     - `ruby scripts/generate_typescript_structs.rb`

8. Sorbet + CI
   - Run `scripts/typecheck.sh` (must be clean).
   - Run `scripts/test.rb` and `scripts/rails_tests.sh` (must be green).
   - CI will enforce Tapioca verification and coverage threshold (80%+ merged).

**Patterns to Follow (Examples)**

- GoodJob:
  - Log type: `lib/log_struct/log/good_job.rb`
  - Integration: `lib/log_struct/integrations/good_job.rb` (+ `logger.rb`, `log_subscriber.rb`)
  - Toggle: `enable_goodjob`
- SQL (ActiveRecord):
  - Log type: `lib/log_struct/log/sql.rb`
  - Integration: `lib/log_struct/integrations/active_record.rb`
  - Toggle: `enable_sql_logging`
- ActiveModelSerializers:
  - Log type: `lib/log_struct/log/active_model_serializers.rb` (msg: "ams.render")
  - Integration: `lib/log_struct/integrations/active_model_serializers.rb`
  - Toggle: `enable_active_model_serializers`
- Ahoy:
  - Log type: `lib/log_struct/log/ahoy.rb` (msg: "ahoy.track")
  - Integration: `lib/log_struct/integrations/ahoy.rb`
  - Toggle: `enable_ahoy`

**Gotchas**

- Don’t emit generic/plain logs for integrations that deserve a first‑class type.
- Keep message names short and stable; avoid dumping raw payloads into `msg`.
- Don’t raise in integration hooks; always call `handle_exception` with the correct `Source`.

**One‑Time Commands (after adding or changing log types)**

- `bundle install`
- `bundle exec tapioca gems`
- `ruby scripts/generate_typescript_structs.rb`
- `scripts/typecheck.sh`
- `scripts/test.rb` and (optionally) `scripts/rails_tests.sh`
