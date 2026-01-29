# typed: strict
# frozen_string_literal: true

require "active_support/notifications"

module LogStruct
  module Integrations
    # ActiveModelSerializers integration. Subscribes to AMS notifications and
    # emits structured logs with serializer/adapter/duration details.
    module ActiveModelSerializers
      extend T::Sig

      sig { params(config: LogStruct::Configuration).returns(T.nilable(TrueClass)) }
      def self.setup(config)
        return nil unless defined?(::ActiveSupport::Notifications)

        # Only activate if AMS appears to be present
        return nil unless defined?(::ActiveModelSerializers)

        # Subscribe to common AMS notification names; keep broad but specific
        pattern = /\.active_model_serializers\z/

        ::ActiveSupport::Notifications.subscribe(pattern) do |_name, started, finished, _unique_id, payload|
          # started/finished are Time; convert to ms
          duration_ms = ((finished - started) * 1000.0).round(3)

          serializer = payload[:serializer] || payload[:serializer_class]
          adapter = payload[:adapter]
          resource = payload[:resource] || payload[:object]

          LogStruct.info(
            LogStruct::Log::ActiveModelSerializers.new(
              message: "ams.render",
              serializer: serializer&.name,
              adapter: adapter&.class&.name,
              resource_class: resource&.class&.name,
              duration_ms: duration_ms,
              timestamp: started
            )
          )
        rescue => e
          LogStruct.handle_exception(e, source: LogStruct::Source::Rails, context: {integration: :active_model_serializers})
        end

        true
      end
    end
  end
end
