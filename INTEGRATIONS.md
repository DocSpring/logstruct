# Adding an integration

Built-in log types come from the YAML files in `schemas/log_sources/`. Never edit the generated Ruby
classes under `lib/log_struct/log/` or the TypeScript files under `docs/generated/` by hand.

## Define the log type

1. Add a schema under `schemas/log_sources/<name>.yml`. See [schemas/README.md](schemas/README.md)
   for the schema format. Use an existing `Source` and `Event`, or add their enum values under
   `lib/log_struct/enums/` first. Every known field belongs in the schema; `additional_data` is for
   unknown fields supplied by an app or integration.
2. Add any new field names and their serialized keys to `lib/log_struct/enums/log_field.rb`.
3. Add the new source's require to `lib/log_struct/log.rb`.
4. Run `task generate` to generate the Ruby classes, TypeScript types, field schema and provider catalog. The script writes the Ruby classes before loading them for the type export.

For example, the Ahoy schema defines a single `LogStruct::Log::Ahoy` class:

```yaml
source: Ahoy
consts:
  source: Source::App
events:
  Log:
    fields:
      Message: String
      AhoyEvent: String
      Properties:
        type: 'T::Hash[Symbol, T.untyped]'
        required: false
```

Multiple events produce a parent file and one class per event, such as `LogStruct::Log::ActiveJob::Start`.
Fields are required unless the schema sets `default_required: false` or an individual field sets
`required: false`.

## Connect the integration

1. Add `prop :enable_<name>, T::Boolean, default: true` to `ConfigStruct::Integrations`.
2. Implement `LogStruct::Integrations::<Name>` under `lib/log_struct/integrations/<name>.rb`.
   Extend `IntegrationInterface`, and give `setup` this signature:

   ```ruby
   sig { override.params(config: LogStruct::Configuration).returns(T.nilable(T::Boolean)) }
   ```

   Return `nil` when LogStruct or the integration is disabled, or its optional gem is absent. Use
   `::` for external constants. Subscribe to the gem's events, build the generated log struct, and
   pass it to `LogStruct.info`, `warn` or `error` as appropriate.

3. Require the integration from `lib/log_struct/integrations.rb` and call its setup in the appropriate
   stage: `:non_middleware` for subscribers and hooks, `:middleware` for Rack stack changes.
4. When replacing an existing log subscriber, detach the original so each event is logged once.
   Keep exceptions and return values behaving as the underlying gem expects. Use
   `LogStruct.handle_exception(error, source: Source::Internal)` for failures inside the integration;
   its configured mode decides whether to raise, log or report the error.
5. Add optional third-party gems as development dependencies in `logstruct.gemspec`, run `bundle install`,
   and generate their RBIs with `bundle exec tapioca gems`. They must not become required runtime
   dependencies just to support an optional integration.

Follow `integrations/ahoy.rb` for a small integration, or `integrations/active_job/log_subscriber.rb`
for an integration with several events.

## Test and document it

- Add tests under `test/log_struct/integrations/`. Exercise real events and inspect the emitted JSON:
  source, event, level, timestamps, expected fields, filtering, errors and duplicate lines.
- Add Rails integration tests under `rails_test_app/templates/test/integration/` where boot order or
  framework behavior matters. The test runner copies these templates into its generated app.
- Add the toggle to the configuration examples in `test/code_examples/configuration_test.rb`, which
  supply the code shown on the docs site.
- Add the title, description and any detail-page link to `docs/lib/integration-helpers.ts`.
  `AllLogTypes` supplies the integration list. Update `docs/lib/gem-descriptions.ts` for an optional gem.
- Run `task generate`, `task ci`, and `cd docs && pnpm check` before calling the work ready.

The generator writes the provider catalog under `terraform-provider-logstruct/pkg/data/`, a path
ignored by this repository. When working in the separate provider checkout, commit its changes from
that repository.
