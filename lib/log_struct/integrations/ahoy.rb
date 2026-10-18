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

            # Takes whatever Ahoy's track takes and passes it on as given, so Ahoy's defaults still apply
            sig { params(name: T.untyped, args: T.untyped).returns(T.untyped) }
            def track(name, *args)
              result = super
              begin
                LogStruct.info(
                  LogStruct::Log::Ahoy.new(
                    message: "ahoy.track",
                    ahoy_event: name.to_s,
                    properties: Integrations::Ahoy.properties_for_log(args.first)
                  )
                )
              rescue => e
                # A problem with the log line is LogStruct's, and never fails the app's tracking call in production
                LogStruct.handle_exception(e, source: LogStruct::Source::Internal, context: {integration: :ahoy})
              end
              result
            end
          end

          ::Ahoy::Tracker.prepend(mod)
        end

        true
      end

      # Event properties can come from the browser, so they can be anything; a non-Hash is logged as its class
      sig { params(properties: T.untyped).returns(T.nilable(T::Hash[Symbol, T.untyped])) }
      def self.properties_for_log(properties)
        properties = properties.to_unsafe_h if properties.respond_to?(:to_unsafe_h)
        case properties
        when nil then nil
        when Hash then properties.to_h { |key, value| [key.to_s.to_sym, value] }
        else {_class: properties.class.name}
        end
      end
    end
  end
end
