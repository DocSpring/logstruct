# typed: strict
# frozen_string_literal: true

module LogStruct
  module Integrations
    # Ahoy analytics integration. If Ahoy is present, prepend a small hook to
    # Ahoy::Tracker#track to emit a structured log for analytics events.
    module Ahoy
      extend T::Sig

      sig { params(config: LogStruct::Configuration).returns(T.nilable(TrueClass)) }
      def self.setup(config)
        return nil unless defined?(::Ahoy)

        if defined?(::Ahoy::Tracker)
          mod = Module.new do
            extend T::Sig

            sig { params(name: T.untyped, properties: T.nilable(T::Hash[T.untyped, T.untyped]), options: T.untyped).returns(T.untyped) }
            def track(name, properties = nil, options = {})
              result = super
              begin
                # Emit a lightweight structured log about the analytics event
                data = {
                  ahoy_event: T.let(name, T.untyped)
                }
                data[:properties] = properties if properties
                LogStruct.info(
                  LogStruct::Log::Ahoy.new(
                    message: "ahoy.track",
                    ahoy_event: T.must(T.let(name, T.nilable(String))),
                    properties: T.let(
                      properties && properties.transform_keys { |k| k.to_sym },
                      T.nilable(T::Hash[Symbol, T.untyped])
                    ),
                    additional_data: {}
                  )
                )
              rescue => e
                # Never raise from logging; rely on global error handling policies
                LogStruct.handle_exception(e, source: LogStruct::Source::App, context: {integration: :ahoy})
              end
              result
            end
          end

          T.unsafe(::Ahoy::Tracker).prepend(mod)
        end

        true
      end
    end
  end
end
