# typed: strict
# frozen_string_literal: true

require "openssl"
require "securerandom"

module LogStruct
  # Utility module for hashing sensitive data
  module HashUtils
    FALLBACK_KEY = T.let(::SecureRandom.random_bytes(32).freeze, String)

    class << self
      extend T::Sig

      # An HMAC-SHA256 of the value, so lines about the same email can be traced without logging it
      sig { params(value: String).returns(String) }
      def hash_value(value)
        length = LogStruct.config.filters.hash_length
        max_bytes = LogStruct.config.limits.max_string_bytes
        input = if value.bytesize > max_bytes
          value.byteslice(0, max_bytes).to_s.b + "\0".b + value.bytesize.to_s.b
        else
          value
        end
        OpenSSL::HMAC.hexdigest("SHA256", hash_key, input)[0...length] || "error"
      end

      # The configured hash_salt, or a key derived from the app's secret_key_base
      sig { returns(String) }
      def hash_key
        LogStruct.config.filters.hash_salt || derived_key || FALLBACK_KEY
      end

      # Forget the derived key (for tests that change the Rails app)
      sig { void }
      def reset!
        @derived_key = T.let(nil, T.nilable(String))
      end

      private

      sig { returns(T.nilable(String)) }
      def derived_key
        @derived_key ||= T.let(begin
          application = ::Rails.application if defined?(::Rails) && ::Rails.respond_to?(:application)
          # Rails derives keys like this one for cookies and messages; nil until the app has its secret
          application&.key_generator&.generate_key("LogStruct hashed values", 32)
        rescue
          nil
        end,
          T.nilable(String))
      end
    end
  end
end
