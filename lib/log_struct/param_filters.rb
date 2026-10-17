# typed: strict
# frozen_string_literal: true

require "json"
require_relative "hash_utils"
require_relative "config_struct/filters"
require_relative "enums/source"

module LogStruct
  # This class contains methods for filtering sensitive data in logs
  # It is used by Formatter to determine which keys should be filtered
  class ParamFilters
    class << self
      extend T::Sig

      # Check if a key should be filtered based on our defined sensitive keys.
      # logstruct_field: the key is one of LogStruct's own fields at the top of a line.
      # path: the keys from the line's top-level field down to this one (the key alone if not given).
      # root: the top-level field's value, or the whole line for a top-level key.
      sig do
        params(
          key: T.untyped,
          value: T.untyped,
          logstruct_field: T::Boolean,
          path: T.nilable(T::Array[String]),
          root: T.untyped
        ).returns(T::Boolean)
      end
      def should_filter_key?(key, value = nil, logstruct_field: false, path: nil, root: nil)
        filters = LogStruct.config.filters
        normalized_key = key.to_s

        return true if filters.filter_keys.include?(normalized_key.downcase.to_sym)
        # By its words too, so :api_key filters apiKey and X-Api-Key
        return true if filters.filter_keys.include?(KeyWords.normalize(normalized_key).to_sym)

        matched = filters.filter_matchers.any? do |matcher|
          next false if logstruct_field && !matcher.matches_logstruct_fields

          matcher.matches?(normalized_key, value)
        rescue => e
          handle_filter_matcher_error(e, matcher.label, normalized_key)
          false
        end
        return true if matched
        return false if filters.path_matchers.empty?

        path ||= [normalized_key]
        root = {} if root.nil?
        filters.path_matchers.any? do |matcher|
          matcher.matches?(path, value, root)
        rescue => e
          handle_filter_matcher_error(e, matcher.label, normalized_key)
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

      # Summarize a filtered String: its class, and an HMAC of it for keys in filter_keys_with_hashes.
      # No length, which would say how long a password or token is.
      sig { params(string: String, include_hash: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
      def summarize_string(string, include_hash)
        filtered_string = {
          _class: String
        }
        filtered_string[:_hash] = HashUtils.hash_value(string) if include_hash

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
        unless has_sensitive_keys
          bytes = json_bytesize(hash)
          summary[:_bytes] = bytes if bytes
        end

        summary
      end

      # Summarize an Array for logging, including details about the size and items
      sig { params(array: T::Array[T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def summarize_array(array)
        return {_class: "Array", _empty: true} if array.empty?

        summary = {
          _class: Array,
          _count: array.size
        }
        bytes = json_bytesize(array)
        summary[:_bytes] = bytes if bytes

        summary
      end

      # The size of a filtered Hash or Array as JSON. JSON.generate stops at its nesting limit,
      # which a circular reference reaches, and writes other objects with to_s instead of walking
      # their attributes. nil when the value can't be written as JSON.
      sig { params(value: T.any(T::Hash[T.untyped, T.untyped], T::Array[T.untyped])).returns(T.nilable(Integer)) }
      def json_bytesize(value)
        ::JSON.generate(value).bytesize
      rescue ::JSON::NestingError, ::JSON::GeneratorError
        nil
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

      sig { params(error: StandardError, label: String, key: String).void }
      def handle_filter_matcher_error(error, label, key)
        context = {
          matcher: label,
          key: key
        }
        LogStruct.handle_exception(error, source: Source::Internal, context: context)
      end
    end
  end
end
