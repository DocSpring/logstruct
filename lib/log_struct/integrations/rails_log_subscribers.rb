# typed: strict
# frozen_string_literal: true

module LogStruct
  module Integrations
    # Rails' own log subscribers, which LogStruct's lines replace
    module RailsLogSubscribers
      extend T::Sig

      # Detaches a framework's log subscriber (ActiveStorage::LogSubscriber, :active_storage). Up to Rails 8.1 it's an
      # ActiveSupport::LogSubscriber attached to the framework's notifications; from Rails 8.2 it's an
      # ActiveSupport::EventReporter::LogSubscriber, subscribed to Rails.event when its file loads.
      sig { params(subscriber_class: T.untyped, namespace: Symbol).void }
      def self.detach(subscriber_class, namespace)
        if subscriber_class.respond_to?(:detach_from)
          subscriber_class.detach_from(namespace)
        else
          unsubscribe_from_events(subscriber_class)
        end
      end

      # Unsubscribes a Rails 8.2 log subscriber from Rails.event. Does nothing for one that isn't subscribed there.
      sig { params(subscriber_class: T.untyped).void }
      def self.unsubscribe_from_events(subscriber_class)
        return unless ::ActiveSupport.respond_to?(:event_reporter)

        reporter = ::ActiveSupport.event_reporter
        reporter.unsubscribe(subscriber_class) if reporter.respond_to?(:unsubscribe)
      end
    end
  end
end
