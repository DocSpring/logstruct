# typed: strict
# frozen_string_literal: true

module LogStruct
  # Enum for error sources
  class ErrorSource < T::Enum
    enums do
      # Errors from type checking (Sorbet, etc)
      TypeChecking = new
      # Errors from LogStruct itself (e.g. scrubbing, filtering, JSON formatting)
      LogStruct = new
      # Security-related errors (CSRF, IP spoofing)
      Security = new
      # Errors from request handling
      Request = new
      # Application errors that don't fit into other categories
      Application = new
    end
  end
end
