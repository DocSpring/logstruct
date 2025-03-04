# typed: strict
# frozen_string_literal: true

require_relative "untyped/error_handling"
require_relative "untyped/integrations"
require_relative "untyped/filters"

module LogStruct
  class Configuration
    # Ruby-style configuration API that uses symbols and hashes
    class Untyped
      sig { params(config: Configuration).void }
      def initialize(config)
        @config = config
        @error_handling = T.let(ErrorHandling.new(config.error_handling), ErrorHandling)
        @integrations = T.let(Integrations.new(config.integrations), Integrations)
        @filters = T.let(Filters.new(config.filters), Filters)
      end

      # -------------------------------------------------------------------------------------
      # Error Handling
      # -------------------------------------------------------------------------------------

      sig { returns(ErrorHandling) }
      attr_reader :error_handling

      # -------------------------------------------------------------------------------------
      # Integrations
      # -------------------------------------------------------------------------------------

      sig { returns(Integrations) }
      attr_reader :integrations

      sig { params(enabled: T::Boolean).void }
      def enabled=(enabled)
        @config.enabled = enabled
      end

      sig { params(integration: Symbol, enabled: T::Boolean).void }
      def set_enabled_for(integration, enabled)
        case integration
        when :lograge
          integrations.lograge_enabled = enabled
        when :emails
          integrations.emails_enabled = enabled
        else
          raise ArgumentError, "Unknown integration: #{integration}"
        end
      end

      # -------------------------------------------------------------------------------------
      # Filter
      # -------------------------------------------------------------------------------------

      sig { returns(Filters) }
      attr_reader :filters

      sig { params(enabled: T::Boolean).void }
      def filter_enabled=(enabled)
        @config.filters.filter_enabled = enabled
      end

      sig { params(key: Symbol, enabled: T::Boolean).void }
      def set_filter_enabled_for(key, enabled)
        case key
        when :emails
          @config.filters.filter_emails = enabled
        when :phone_numbers
          @config.filters.filter_phone_numbers = enabled
        when :credit_cards
          @config.filters.filter_credit_cards = enabled
        else
          raise ArgumentError, "Unknown filter key: #{key}"
        end
      end

      sig { params(keys: T::Array[Symbol]).void }
      def filtered_keys=(keys)
        @config.filters.filtered_keys = keys
      end

      sig { params(keys: T::Array[Symbol]).void }
      def hashed_keys=(keys)
        @config.filters.hashed_keys = keys
      end

      sig { params(salt: String).void }
      def hash_salt=(salt)
        @config.filters.hash_salt = salt
      end

      sig { params(length: Integer).void }
      def hash_length=(length)
        @config.filters.hash_length = length
      end

      # -------------------------------------------------------------------------------------
      # Environment Settings
      # -------------------------------------------------------------------------------------

      sig { params(environments: T::Array[Symbol]).void }
      def environments=(environments)
        @config.environments = environments
      end

      sig { params(environments: T::Array[Symbol]).void }
      def local_environments=(environments)
        @config.local_environments = environments
      end
    end
  end
end
