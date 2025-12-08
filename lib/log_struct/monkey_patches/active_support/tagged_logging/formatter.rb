# typed: strict
# frozen_string_literal: true

require "active_support/tagged_logging"

# Monkey-patch ActiveSupport::TaggedLogging::Formatter to work with structured logging.
#
# Problem: Rails' TaggedLogging prepends tags as text and converts messages to strings.
# When we pass a hash to super(), Rails does "#{tags_text}#{msg}" which calls .to_s
# on the hash, producing Ruby inspect format {message: "..."} instead of valid JSON.
#
# Solution: When LogStruct is enabled, we add tags as a hash entry and delegate to
# LogStruct::Formatter for proper JSON serialization with filtering and standard fields.
module ActiveSupport
  module TaggedLogging
    extend T::Sig

    # Add class-level current_tags method for compatibility with Rails code
    sig { returns(T::Array[T.any(String, Symbol)]) }
    def self.current_tags
      Thread.current[:activesupport_tagged_logging_tags] || []
    end

    module FormatterExtension
      extend T::Sig
      extend T::Helpers
      requires_ancestor { ::ActiveSupport::TaggedLogging::Formatter }

      sig { params(severity: T.any(String, Symbol), time: Time, progname: T.untyped, data: T.untyped).returns(String) }
      def call(severity, time, progname, data)
        # Preserve original Rails behavior when LogStruct is disabled
        return super unless ::LogStruct.enabled?

        # Get current tags
        tags = T.unsafe(self).respond_to?(:current_tags) ? current_tags : (Thread.current[:activesupport_tagged_logging_tags] || [])

        # Add tags to data as hash entry (not text prefix)
        data_with_tags = if data.is_a?(Hash)
          tags.present? ? data.merge(tags: tags) : data
        elsif data.is_a?(::LogStruct::Log::Interfaces::CommonFields) || (data.is_a?(T::Struct) && data.respond_to?(:serialize))
          hash = T.unsafe(data).serialize
          tags.present? ? hash.merge(tags: tags) : hash
        else
          tags.present? ? {message: data.to_s, tags: tags} : {message: data.to_s}
        end

        # Delegate to LogStruct::Formatter for JSON serialization with filtering
        logstruct_formatter.call(severity, time, progname, data_with_tags)
      end

      private

      sig { returns(::LogStruct::Formatter) }
      def logstruct_formatter
        @logstruct_formatter ||= T.let(::LogStruct::Formatter.new, T.nilable(::LogStruct::Formatter))
      end
    end
  end
end

ActiveSupport::TaggedLogging::Formatter.prepend(ActiveSupport::TaggedLogging::FormatterExtension)
