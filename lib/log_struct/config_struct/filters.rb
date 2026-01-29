# typed: strict
# frozen_string_literal: true

module LogStruct
  module ConfigStruct
    class FilterMatcher < T::Struct
      extend T::Sig

      const :callable, T.proc.params(key: String, value: T.untyped).returns(T::Boolean)
      const :label, String

      sig { params(key: String, value: T.untyped).returns(T::Boolean) }
      def matches?(key, value)
        callable.call(key, value)
      end
    end

    class Filters < T::Struct
      include Sorbet::SerializeSymbolKeys

      # Keys that should be filtered in nested structures such as request params and job arguments.
      # Filtered data includes information about Hashes and Arrays.
      #
      # { _filtered: {
      #     _class: "Hash",                # Class of the filtered value
      #     _bytes: 1234,                  # Length of JSON string in bytes
      #     _keys_count: 3,                # Number of keys in the hash
      #     _keys: [:key1, :key2, :key3],  # First 10 keys in the hash
      #   }
      # }
      #
      # Default: [:password, :password_confirmation, :pass, :pw, :token, :secret,
      #           :credentials, :creds, :auth, :authentication, :authorization]
      #
      prop :filter_keys,
        T::Array[Symbol],
        factory: -> {
          %i[
            password password_confirmation pass pw token secret
            credentials auth authentication authorization
            credit_card ssn social_security
          ]
        }

      # Keys where string values should include an SHA256 hash.
      # Useful for tracing emails across requests (e.g. sign in, sign up) while protecting privacy.
      # Default: [:email, :email_address]
      prop :filter_keys_with_hashes,
        T::Array[Symbol],
        factory: -> { %i[email email_address] }

      # Hash salt for SHA256 hashing (typically used for email addresses)
      # Used for both param filters and string scrubbing
      # Default: "l0g5t0p"
      prop :hash_salt, String, default: "l0g5t0p"

      # Hash length for SHA256 hashing (typically used for email addresses)
      # Used for both param filters and string scrubbing
      # Default: 12
      prop :hash_length, Integer, default: 12

      # Filter email addresses. Also controls email filtering for the ActionMailer integration
      # (to, from, recipient fields, etc.)
      # Default: true
      prop :email_addresses, T::Boolean, default: true

      # Filter URL passwords
      # Default: true
      prop :url_passwords, T::Boolean, default: true

      # Filter credit card numbers
      # Default: true
      prop :credit_card_numbers, T::Boolean, default: true

      # Filter phone numbers
      # Default: true
      prop :phone_numbers, T::Boolean, default: true

      # Filter social security numbers
      # Default: true
      prop :ssns, T::Boolean, default: true

      # Filter IP addresses
      # Default: false
      prop :ip_addresses, T::Boolean, default: false

      # Filter MAC addresses
      # Default: false
      prop :mac_addresses, T::Boolean, default: false

      # Default regex pattern for matching sensitive keys.
      # Matches keys containing: password, token, secret, auth, cred
      # Also matches specific key patterns: api_key, secret_key, private_key, access_key, encryption_key
      # Examples: access_token, api_key, auth_header, credentials
      # Uses start/end of string or underscore/hyphen boundaries to prevent
      # false positives like "keyboard" or "turkey" (which contain "key" mid-word)
      # Note: "key" alone is too broad (matches cron_key, primary_key), so we only match
      # specific sensitive key patterns
      DEFAULT_SENSITIVE_KEY_PATTERN = T.let(
        /(^|[_-])(password|token|secret|auth|cred)([_-]|$)|(^|[_-])(api|secret|private|access|encryption)_key([_-]|$)/i,
        Regexp
      )

      # Additional filter matchers built from Rails filter_parameters entries that aren't simple symbols.
      # Each matcher receives the key (String) and optional value, returning true when the pair should be filtered.
      # By default, includes a regex matcher for common sensitive key patterns.
      prop :filter_matchers,
        T::Array[FilterMatcher],
        factory: -> {
          [
            FilterMatcher.new(
              callable: ->(key, _value) { DEFAULT_SENSITIVE_KEY_PATTERN.match?(key) },
              label: "default_sensitive_pattern"
            )
          ]
        }
    end
  end
end
