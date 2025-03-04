# typed: strict
# frozen_string_literal: true

module LogStruct
  module Untyped
    class Configuration
      class Filters
        extend T::Sig

        sig { params(typed: LogStruct::Configuration::Filters).void }
        def initialize(typed)
          @typed = T.let(typed, LogStruct::Configuration::Filters)
        end

        sig { params(enabled: T::Boolean).void }
        def filter_emails=(enabled)
          @typed.filter_emails = enabled
        end

        sig { params(enabled: T::Boolean).void }
        def filter_phones=(enabled)
          @typed.filter_phones = enabled
        end

        sig { params(enabled: T::Boolean).void }
        def filter_credit_cards=(enabled)
          @typed.filter_credit_cards = enabled
        end

        sig { params(enabled: T::Boolean).void }
        def filter_url_passwords=(enabled)
          @typed.filter_url_passwords = enabled
        end

        sig { params(enabled: T::Boolean).void }
        def filter_ssns=(enabled)
          @typed.filter_ssns = enabled
        end

        sig { params(enabled: T::Boolean).void }
        def filter_ips=(enabled)
          @typed.filter_ips = enabled
        end

        sig { params(enabled: T::Boolean).void }
        def filter_macs=(enabled)
          @typed.filter_macs = enabled
        end

        sig { params(keys: T::Array[Symbol]).void }
        def filtered_keys=(keys)
          @typed.filtered_keys = keys
        end

        sig { params(keys: T::Array[Symbol]).void }
        def filtered_keys_with_string_hash=(keys)
          @typed.filtered_keys_with_string_hash = keys
        end

        sig { params(salt: String).void }
        def hash_salt=(salt)
          @typed.hash_salt = salt
        end

        sig { params(length: Integer).void }
        def hash_length=(length)
          @typed.hash_length = length
        end

        sig { params(handler: T.nilable(LogStruct::CustomHandlers::StringScrubber)).void }
        def string_scrubbing_handler=(handler)
          @typed.string_scrubbing_handler = handler
        end

        sig { params(settings: T::Hash[Symbol, T.untyped]).void }
        def configure(settings)
          settings.each do |key, value|
            case key
            when :filter_emails then self.filter_emails = T.cast(value, T::Boolean)
            when :filter_phones then self.filter_phones = T.cast(value, T::Boolean)
            when :filter_credit_cards then self.filter_credit_cards = T.cast(value, T::Boolean)
            when :filter_url_passwords then self.filter_url_passwords = T.cast(value, T::Boolean)
            when :filter_ssns then self.filter_ssns = T.cast(value, T::Boolean)
            when :filter_ips then self.filter_ips = T.cast(value, T::Boolean)
            when :filter_macs then self.filter_macs = T.cast(value, T::Boolean)
            when :filtered_keys then self.filtered_keys = T.cast(value, T::Array[Symbol])
            when :filtered_keys_with_string_hash then self.filtered_keys_with_string_hash = T.cast(value, T::Array[Symbol])
            when :hash_salt then self.hash_salt = T.cast(value, String)
            when :hash_length then self.hash_length = T.cast(value, Integer)
            when :string_scrubbing_handler then self.string_scrubbing_handler = T.cast(value, T.nilable(LogStruct::CustomHandlers::StringScrubber))
            else
              raise ArgumentError, "Unknown filter setting: #{key}"
            end
          end
        end
      end
    end
  end
end
