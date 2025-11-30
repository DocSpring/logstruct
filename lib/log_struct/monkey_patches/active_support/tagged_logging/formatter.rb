# typed: strict
# frozen_string_literal: true

require "active_support/tagged_logging"

# Monkey-patch ActiveSupport::TaggedLogging::Formatter to support hash inputs
# This allows us to pass structured data to the logger and have tags incorporated
# directly into the hash instead of being prepended as strings
module ActiveSupport
  module TaggedLogging
    extend T::Sig

    # Add class-level current_tags method for compatibility with Rails code
    # that expects to call ActiveSupport::TaggedLogging.current_tags
    # Use thread-local storage directly like Rails does internally
    sig { returns(T::Array[T.any(String, Symbol)]) }
    def self.current_tags
      Thread.current[:activesupport_tagged_logging_tags] || []
    end

    module FormatterExtension
      extend T::Sig
      extend T::Helpers
      requires_ancestor { ::ActiveSupport::TaggedLogging::Formatter }

      # Override the call method to support hash input/output, and wrap
      # plain strings in a Hash under a `msg` key.
      # The data is then passed to our custom log formatter that transforms it
      # into a JSON string before logging.
      #
      # IMPORTANT: This only applies when LogStruct is enabled. When disabled,
      # we preserve the original Rails logging behavior to avoid wrapping
      # messages in hashes (which would break default Rails log formatting).
      sig { params(severity: T.any(String, Symbol), time: Time, progname: T.untyped, data: T.untyped).returns(String) }
      def call(severity, time, progname, data)
        # Skip hash wrapping when LogStruct is disabled to preserve default Rails behavior
        return super unless ::LogStruct.enabled?

        # Convert data to a hash if it's not already one
        data = {message: data.to_s} unless data.is_a?(Hash)

        # Add current tags to the hash if present
        # Use thread-local storage directly as fallback if current_tags method doesn't exist
        tags = T.unsafe(self).respond_to?(:current_tags) ? current_tags : (Thread.current[:activesupport_tagged_logging_tags] || [])
        data[:tags] = tags if tags.present?

        # Call the original formatter with our enhanced data
        super
      end
    end
  end
end

ActiveSupport::TaggedLogging::Formatter.prepend(ActiveSupport::TaggedLogging::FormatterExtension)
