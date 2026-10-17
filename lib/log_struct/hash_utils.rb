# typed: strict
# frozen_string_literal: true

require "openssl"

module LogStruct
  # Utility module for hashing sensitive data
  module HashUtils
    # The key when there's neither a configured hash_salt nor a Rails app with a secret_key_base.
    # It's public, so these hashes can be matched to a list of candidate values.
    FALLBACK_KEY = "l0g5t0p"

    class << self
      extend T::Sig

      # An HMAC-SHA256 of the value, so lines about the same email can be traced without logging it
      sig { params(value: String).returns(String) }
      def hash_value(value)
        length = LogStruct.config.filters.hash_length
        OpenSSL::HMAC.hexdigest("SHA256", hash_key, value)[0...length] || "error"
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
