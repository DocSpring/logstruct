# typed: strict
# frozen_string_literal: true

module LogStruct
  class Configuration
    # Configuration for filtering sensitive data
    class Filter
      extend T::Sig

      # Default filter settings
      DEFAULT_FILTERS = T.let(
        {
          emails: true,
          url_passwords: true,
          credit_cards: true,
          phones: true,
          ssns: true,
          ips: false,
          macs: false
        }.freeze,
        T::Hash[Symbol, T::Boolean]
      )

      # Default keys to filter in nested structures
      DEFAULT_FILTERED_KEYS = T.let(
        %i[
          password password_confirmation pass pw token secret
          credentials auth authentication authorization
          credit_card ssn social_security
        ].freeze,
        T::Array[Symbol]
      )

      # Default keys to hash rather than filter
      DEFAULT_HASHED_KEYS = T.let(
        %i[
          email email_address
        ].freeze,
        T::Array[Symbol]
      )

      sig { returns(T::Hash[Symbol, T::Boolean]) }
      attr_reader :enabled

      sig { returns(T::Array[Symbol]) }
      attr_reader :filtered_keys

      sig { returns(T::Array[Symbol]) }
      attr_reader :hashed_keys

      sig { returns(String) }
      attr_accessor :hash_salt

      sig { returns(Integer) }
      attr_accessor :hash_length

      sig { void }
      def initialize
        @enabled = T.let(DEFAULT_FILTERS.dup, T::Hash[Symbol, T::Boolean])
        @filtered_keys = T.let(DEFAULT_FILTERED_KEYS.dup, T::Array[Symbol])
        @hashed_keys = T.let(DEFAULT_HASHED_KEYS.dup, T::Array[Symbol])
        @hash_salt = T.let("l0g5t0p", String)
        @hash_length = T.let(12, Integer)
      end

      # Ruby-style configuration API
      # Example: config.enabled = false
      sig { params(enabled: T::Boolean).void }
      def enabled=(enabled)
        @enabled.each_key do |key|
          set_enabled_for_enum(key, enabled)
        end
      end

      # Type-checked configuration API
      # Example: config.set_enabled(false)
      sig { params(enabled: T::Boolean).void }
      def set_enabled(enabled)
        @enabled.each_key do |key|
          set_enabled_for_enum(key, enabled)
        end
      end

      # Set enabled state for a specific filter via symbol
      # Example: config.emails = false
      sig { params(key: Symbol, enabled: T::Boolean).void }
      def set_enabled_for(key, enabled)
        validate_key!(key)
        @enabled[key] = enabled
      end

      # Set enabled state for a specific filter via enum
      # Example: config.set_enabled_for_enum(:emails, false)
      sig { params(key: Symbol, enabled: T::Boolean).void }
      def set_enabled_for_enum(key, enabled)
        validate_key!(key)
        @enabled[key] = enabled
      end

      # Get enabled state for a key
      sig { params(key: Symbol).returns(T::Boolean) }
      def get_enabled(key)
        validate_key!(key)
        T.must(@enabled[key])
      end

      # Set filtered keys
      sig { params(keys: T.any(T::Array[Symbol], T::Array[String])).void }
      def filtered_keys=(keys)
        @filtered_keys = Array(keys).map { |v| v.to_s.downcase.to_sym }.freeze
      end

      # Set hashed keys
      sig { params(keys: T.any(T::Array[Symbol], T::Array[String])).void }
      def hashed_keys=(keys)
        @hashed_keys = Array(keys).map { |v| v.to_s.downcase.to_sym }.freeze
      end

      private

      sig { params(key: Symbol).void }
      def validate_key!(key)
        unless DEFAULT_FILTERS.key?(key)
          raise ArgumentError, "Invalid filter key: #{key}"
        end
      end
    end
  end
end
