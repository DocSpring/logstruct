# frozen_string_literal: true

# Monkey-patch ActiveSupport::TaggedLogging::Formatter to support hash inputs
# This allows us to pass structured data to the logger and have tags incorporated
# directly into the hash instead of being prepended as strings
module ActiveSupport
  module TaggedLogging
    module FormatterExtension
      # Override the call method to handle hash inputs
      def call(severity, time, progname, data)
        # Convert data to a hash if it's not already one
        data = { msg: data.to_s } unless data.is_a?(Hash)

        # Add current tags to the hash if present
        tags = current_tags
        data[:tags] = tags if tags.present?

        # Call the original formatter with our enhanced data
        super
      end
    end
  end
end

# Apply the monkey patch if ActiveSupport::TaggedLogging::Formatter exists
if defined?(ActiveSupport::TaggedLogging)
  ActiveSupport::TaggedLogging::Formatter.prepend(ActiveSupport::TaggedLogging::FormatterExtension)
end
