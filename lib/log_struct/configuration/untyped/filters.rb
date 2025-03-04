# typed: strict
# frozen_string_literal: true

module LogStruct
  class Configuration
    class Untyped
      class Filters
        sig { params(typed: Configuration::Filters).void }
        def initialize(typed)
          @typed = typed
        end

        sig { params(enabled: T::Boolean).void }
        def filter_emails=(enabled)
          @typed.filter_emails = enabled
        end

        sig { params(enabled: T::Boolean).void }
        def filter_phone_numbers=(enabled)
          @typed.filter_phone_numbers = enabled
        end

        sig { params(enabled: T::Boolean).void }
        def filter_credit_cards=(enabled)
          @typed.filter_credit_cards = enabled
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

        sig { params(settings: T::Hash[Symbol, T.any(T::Boolean, T::Array[Symbol], String, Integer)]).void }
        def configure(settings)
          settings.each do |key, value|
            case key
            when :filter_emails then self.filter_emails = T.cast(value, T::Boolean)
            when :filter_phone_numbers then self.filter_phone_numbers = T.cast(value, T::Boolean)
            when :filter_credit_cards then self.filter_credit_cards = T.cast(value, T::Boolean)
            when :filtered_keys then self.filtered_keys = T.cast(value, T::Array[Symbol])
            when :filtered_keys_with_string_hash then self.filtered_keys_with_string_hash = T.cast(value, T::Array[Symbol])
            when :hash_salt then self.hash_salt = T.cast(value, String)
            when :hash_length then self.hash_length = T.cast(value, Integer)
            else
              raise ArgumentError, "Unknown filter setting: #{key}"
            end
          end
        end
      end
    end
  end
end
