# typed: strict
# frozen_string_literal: true

# Common enums and shared interfaces
require_relative "enums/source"
require_relative "enums/event"
require_relative "enums/level"
require_relative "enums/log_field"
require_relative "log/interfaces/public_common_fields"
require_relative "log/shared/serialize_common_public"

# Dynamically require all top-level log structs under log/*
# Nested per-event files are required by their parent files.
Dir[File.join(__dir__, "log", "*.rb")].sort.each do |file|
  require file
end

module LogStruct
  module Log
    extend T::Sig

    # Build an Error log from an exception with optional context and timestamp
    sig do
      params(
        source: Source,
        ex: StandardError,
        additional_data: T::Hash[T.any(String, Symbol), T.untyped],
        timestamp: Time
      ).returns(LogStruct::Log::Error)
    end
    def self.from_exception(source, ex, additional_data = {}, timestamp = Time.now)
      LogStruct::Log::Error.new(
        source: source,
        err_class: ex.class,
        message: ex.message,
        backtrace: ex.backtrace,
        additional_data: additional_data,
        timestamp: timestamp
      )
    end
  end
end
