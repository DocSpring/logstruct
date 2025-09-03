# typed: strict
# frozen_string_literal: true

module Rack
  # Type definitions for Rack middleware

  # Standard Rack response tuple: [status, headers, body]
  # Status is an Integer HTTP status code
  # Headers is a Hash of String keys to String (or Array<String>) values
  # Body is an enumerable that yields strings
  RackResponse = T.type_alias { [Integer, T::Hash[String, T.untyped], T.any(T::Array[String], T::Enumerable[String])] }

  # Rack environment hash
  RackEnv = T.type_alias { T::Hash[String, T.untyped] }

  # Rack application/middleware callable
  # Must respond to #call(env) and return a RackResponse
  RackApp = T.type_alias {
    T.any(
      T.proc.params(env: RackEnv).returns(RackResponse),
      T.untyped  # For objects with #call method
    )
  }
end
