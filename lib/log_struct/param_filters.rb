# typed: strict
# frozen_string_literal: true

require "digest"
require_relative "hash_utils"
require_relative "config_struct/filters"
require_relative "enums/source"

module LogStruct
  # This class contains methods for filtering sensitive data in logs
  # It is used by Formatter to determine which keys should be filtered
  class ParamFilters
    class << self
      extend T::Sig

      # Check if a key should be filtered based on our defined sensitive keys
      sig { params(key: T.untyped, value: T.untyped).returns(T::Boolean) }
      def should_filter_key?(key, value = nil)
        filters = LogStruct.config.filters
        normalized_key = key.to_s
        normalized_symbol = normalized_key.downcase.to_sym

        return true if filters.filter_keys.include?(normalized_symbol)

        filters.filter_matchers.any? do |matcher|
          matcher.matches?(normalized_key, value)
        rescue => e
          handle_filter_matcher_error(e, matcher, normalized_key)
          false
        end
      end

      # Check if a key should be hashed rather than completely filtered
      sig { params(key: T.untyped).returns(T::Boolean) }
      def should_include_string_hash?(key)
        LogStruct.config.filters.filter_keys_with_hashes.include?(key.to_s.downcase.to_sym)
      end

      # Convert a value to a filtered summary hash (e.g. { _filtered: { class: "String", ... }})
      sig { params(key: T.untyped, data: T.untyped).returns(T::Hash[Symbol, T.untyped]) }
      def summarize_json_attribute(key, data)
        case data
        when Hash
          summarize_hash(data)
        when Array
          summarize_array(data)
        when String
          summarize_string(data, should_include_string_hash?(key))
        else
          {_class: data.class}
        end
      end

      # Summarize a String for logging, including details and an SHA256 hash (if configured)
      sig { params(string: String, include_hash: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
      def summarize_string(string, include_hash)
        filtered_string = {
          _class: String
        }
        if include_hash
          filtered_string[:_hash] = HashUtils.hash_value(string)
        else
          filtered_string[:_bytes] = string.bytesize
        end

        filtered_string
      end

      # Summarize a Hash for logging, including details about the size and keys
      sig { params(hash: T::Hash[T.untyped, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def summarize_hash(hash)
        return {_class: "Hash", _empty: true} if hash.empty?

        # Don't include byte size if hash contains any filtered keys
        has_sensitive_keys = T.let(false, T::Boolean)
        normalized_keys = []

        hash.each do |key, value|
          has_sensitive_keys ||= should_filter_key?(key, value)
          normalized_keys << normalize_summary_key(key)
        end

        summary = {
          _class: Hash,
          _keys_count: hash.keys.size,
          _keys: normalized_keys.take(10)
        }

        # Only add byte size if no sensitive keys are present
        summary[:_bytes] = hash.to_json.bytesize unless has_sensitive_keys

        summary
      end

      # Summarize an Array for logging, including details about the size and items
      sig { params(array: T::Array[T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def summarize_array(array)
        return {_class: "Array", _empty: true} if array.empty?

        {
          _class: Array,
          _count: array.size,
          _bytes: array.to_json.bytesize
        }
      end

      private

      sig { params(key: T.any(String, Symbol, Integer, T.untyped)).returns(T.any(Symbol, String)) }
      def normalize_summary_key(key)
        if key.is_a?(Symbol)
          key
        elsif key.respond_to?(:to_sym)
          key.to_sym
        else
          key.to_s
        end
      rescue
        key.to_s
      end

      sig { params(error: StandardError, matcher: ConfigStruct::FilterMatcher, key: String).void }
      def handle_filter_matcher_error(error, matcher, key)
        context = {
          matcher: matcher.label,
          key: key
        }
        LogStruct.handle_exception(error, source: Source::Internal, context: context)
      end
    end
  end
end
