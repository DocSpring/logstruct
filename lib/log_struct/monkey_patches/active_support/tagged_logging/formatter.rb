# typed: true
# frozen_string_literal: true

require "active_support/tagged_logging"

# Monkey-patch ActiveSupport::TaggedLogging::Formatter to support hash inputs
# This allows us to pass structured data to the logger and have tags incorporated
# directly into the hash instead of being prepended as strings
module ActiveSupport
  module TaggedLogging
    module FormatterExtension
      extend T::Helpers
      requires_ancestor { ::ActiveSupport::TaggedLogging::Formatter }

      # Override the call method to support hash input/output, and wrap
      # plain strings in a Hash under a `msg` key.
      # The data is then passed to our custom log formatter that transforms it
      # into a JSON string before logging.
      def call(severity, time, progname, data)
        # Convert data to a hash if it's not already one
        data = {message: data.to_s} unless data.is_a?(Hash)

        # Add current tags to the hash if present
        tags = current_tags
        data[:tags] = tags if tags.present?

        # Call the original formatter with our enhanced data
        super
      end
    end
  end
end

ActiveSupport::TaggedLogging::Formatter.prepend(ActiveSupport::TaggedLogging::FormatterExtension)
