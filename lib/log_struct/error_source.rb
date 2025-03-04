# typed: strict
# frozen_string_literal: true

module LogStruct
  # Enum for error sources
  class ErrorSource < T::Enum
    enums do
      # Errors from Sorbet type checking
      Sorbet = new
      # Errors from LogStruct itself (e.g. scrubbing, filtering, JSON formatting)
      LogStruct = new
      # Security-related errors (CSRF, IP spoofing)
      Security = new
      # Errors from request handling
      Request = new
      # General errors that don't fit into other categories
      General = new
    end
  end
end
