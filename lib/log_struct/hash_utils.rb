# typed: strict
# frozen_string_literal: true

require "digest"

module LogStruct
  # Utility module for hashing sensitive data
  module HashUtils
    class << self
      # Create a hash of a string value for tracing while preserving privacy
      sig { params(value: String).returns(String) }
      def hash_value(value)
        salt = LogStruct.configuration.hash_salt
        length = LogStruct.configuration.hash_length
        Digest::SHA256.hexdigest("#{salt}#{value}")[0...length] || "error"
      end
    end
  end
end
