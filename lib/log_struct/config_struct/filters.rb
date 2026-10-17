# typed: strict
# frozen_string_literal: true

module LogStruct
  # A key's words, lowercase and joined by underscores, so that keys match however they're written:
  # apiKey, api-key, X-Api-Key and HTTP_X_API_KEY all contain "api_key"
  module KeyWords
    extend T::Sig

    sig { params(key: T.untyped).returns(String) }
    def self.normalize(key)
      key.to_s
        .gsub(/([a-z\d])([A-Z])/, '\1_\2')
        .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
        .tr("- .", "___")
        .downcase
    end
  end

  module ConfigStruct
    class FilterMatcher < T::Struct
      extend T::Sig

      const :callable, T.proc.params(key: String, value: T.untyped).returns(T::Boolean)
      const :label, String
      # Whether the matcher also applies to the names of LogStruct's own fields at the top of a line.
      # LogStruct's matcher for Rails' partial matches doesn't: Rails' default :_key would filter cron_key.
      const :matches_logstruct_fields, T::Boolean, default: true

      sig { params(key: String, value: T.untyped).returns(T::Boolean) }
      def matches?(key, value)
        callable.call(key, value)
      end
    end

    # A filter that needs more than the key: Rails' entries with a dot (`card.number`) match a key by its
    # path, and Rails gives filter blocks with three arguments the parameters around the key. The path
    # starts at the line's top-level field (`["params", "card", "number"]`); `root` is that field's value,
    # or the whole line for a top-level key.
    class PathFilterMatcher < T::Struct
      extend T::Sig

      const :callable, T.proc.params(path: T::Array[String], value: T.untyped, root: T.untyped).returns(T::Boolean)
      const :label, String

      sig { params(path: T::Array[String], value: T.untyped, root: T.untyped).returns(T::Boolean) }
      def matches?(path, value, root)
        callable.call(path, value, root)
      end
    end

    class Filters < T::Struct
      include Sorbet::SerializeSymbolKeys

      # Keys that should be filtered in nested structures such as request params and job arguments.
      # A filtered value is replaced by a summary of it:
      #
      # { _filtered: {
      #     _class: "Hash",                # Class of the filtered value
      #     _bytes: 1234,                  # Length as JSON (Hashes without sensitive keys, and Arrays)
      #     _keys_count: 3,                # Number of keys in the hash
      #     _keys: [:key1, :key2, :key3],  # First 10 keys in the hash
      #   }
      # }
      #
      # A filtered String has only its _class (no length), plus its _hash for filter_keys_with_hashes.
      #
      # Names are matched by their words, so :api_key also filters apiKey and X-Api-Key.
      #
      # Default: [:password, :password_confirmation, :pass, :pw, :token, :secret, :credentials, :auth,
      #           :authentication, :authorization, :credit_card, :ssn, :social_security]
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

      # Keys where string values should include a hash (see hash_salt).
      # Useful for tracing emails across requests (e.g. sign in, sign up) while protecting privacy.
      # Default: [:email, :email_address]
      prop :filter_keys_with_hashes,
        T::Array[Symbol],
        factory: -> { %i[email email_address] }

      # The key for the HMAC-SHA256 hashes of emails and filter_keys_with_hashes values. Anyone who has
      # the key and a list of candidate emails can match them to the hashes, so keep it secret.
      # Default: nil, which uses a key derived from the Rails app's secret_key_base. Set it to keep the
      # same hashes in every app that logs the same people.
      prop :hash_salt, T.nilable(String), default: nil

      # How many hex characters of each hash to log
      # Default: 16
      prop :hash_length, Integer, default: 16

      # Filter email addresses. Also controls email filtering for the ActionMailer integration
      # (to, from, recipient fields, etc.)
      # Default: true
      prop :email_addresses, T::Boolean, default: true

      # Filter URL passwords
      # Default: true
      prop :url_passwords, T::Boolean, default: true

      # Filter sensitive params in URLs' query strings: params that filter_keys or the filter matchers
      # would filter as keys (?token=, ?api_key=, user[password]=), and OAuth's ?code=
      # Default: true
      prop :url_query_params, T::Boolean, default: true

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

      # Default pattern for sensitive keys, matched against a key's words joined by underscores
      # (KeyWords.normalize: apiKey, api-key and API_KEY are all "api_key"):
      # - these words anywhere in the key: password, passwd, passphrase, pwd, token, secret, auth,
      #   authorization, authentication, cred, credential, cookie, session, jwt, bearer, otp, cvv, cvc,
      #   ssn, crypt, crypted (and their plurals): access_token, newPassword, Set-Cookie, HTTP_AUTHORIZATION
      # - api_key, secret_key, private_key, access_key, encryption_key, signing_key, master_key: X-Api-Key
      # - signature, sig, salt and certificate as the last word: X-Amz-Signature (but not signature_field_id)
      # Matching whole words avoids false positives like "keyboard", "author" or "cron_key".
      DEFAULT_SENSITIVE_KEY_PATTERN = T.let(
        /(?:\A|_)(?:passwords?|passwd|passphrases?|pwd|tokens?|secrets?|auth|authorization|authentication|creds?|credentials?|cookies?|sessions?|jwts?|bearer|otps?|cvv|cvc|ssn|crypt|crypted)(?:_|\z)|(?:\A|_)(?:api|secret|private|access|encryption|signing|master)_keys?(?:_|\z)|(?:\A|_)(?:signature|sig|salt|certificate)s?\z/,
        Regexp
      )

      # Matchers for keys that aren't listed by name in filter_keys. Each matcher receives the key (String)
      # and optional value, returning true when the pair should be filtered. Includes a regex matcher for
      # common sensitive key patterns, and LogStruct adds matchers for Rails' filter_parameters at boot.
      prop :filter_matchers,
        T::Array[FilterMatcher],
        factory: -> {
          [
            FilterMatcher.new(
              callable: ->(key, _value) { DEFAULT_SENSITIVE_KEY_PATTERN.match?(KeyWords.normalize(key)) },
              label: "default_sensitive_pattern"
            )
          ]
        }

      # Matchers that need a key's path or the parameters around it (see PathFilterMatcher). LogStruct
      # adds them for Rails' filter_parameters at boot.
      prop :path_matchers,
        T::Array[PathFilterMatcher],
        factory: -> { [] }
    end
  end
end
