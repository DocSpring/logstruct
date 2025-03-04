# typed: strict
# frozen_string_literal: true

module LogStruct
  class Filters < T::Struct
    extend T::Sig

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
    prop :filtered_keys, T::Array[Symbol]

    # Keys where string values should include an SHA256 hash.
    # Useful for tracing emails across requests (e.g. sign in, sign up) while protecting privacy.
    # Default: [:email, :email_address]
    prop :filtered_keys_with_string_hash, T::Array[Symbol]

    # Hash salt for SHA256 hashing (typically used for email addresses)
    # Used for both param filters and string scrubbing
    # Default: "l0g5t0p"
    prop :hash_salt, String

    # Hash length for SHA256 hashing (typically used for email addresses)
    # Used for both param filters and string scrubbing
    # Default: 12
    prop :hash_length, Integer

    # Filter email addresses. Also controls email filtering for the ActionMailer integration
    # (to, from, recipient fields, etc.)
    # Default: true
    prop :filter_emails, T::Boolean

    # Filter URL passwords
    # Default: true
    prop :filter_url_passwords, T::Boolean

    # Filter credit card numbers
    # Default: true
    prop :filter_credit_cards, T::Boolean

    # Filter phone numbers
    # Default: true
    prop :filter_phones, T::Boolean

    # Filter social security numbers
    # Default: true
    prop :filter_ssns, T::Boolean

    # Filter IP addresses
    # Default: false
    prop :filter_ips, T::Boolean

    # Filter MAC addresses
    # Default: false
    prop :filter_macs, T::Boolean

    # Custom log scrubbing handler for any additional string scrubbing
    # Default: nil
    prop :string_scrubbing_handler, T.nilable(CustomHandlers::StringScrubber)

    sig { void }
    def initialize
      super(
        filtered_keys: %i[
          password password_confirmation pass pw token secret
          credentials auth authentication authorization
          credit_card ssn social_security
        ],
        filtered_keys_with_string_hash: %i[
          email email_address
        ],
        hash_salt: "l0g5t0p",
        hash_length: 12,
        filter_emails: true,
        filter_url_passwords: true,
        filter_credit_cards: true,
        filter_phones: true,
        filter_ssns: true,
        filter_ips: false,
        filter_macs: false,
        string_scrubbing_handler: nil
      )
    end
  end
end
