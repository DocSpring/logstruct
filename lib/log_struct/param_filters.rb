# typed: strict
# frozen_string_literal: true

require "json"
require_relative "hash_utils"
require_relative "string_scrubber"
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

        words = KeyWords.normalize(normalized_key).to_sym
        # By its words too, so :api_key filters apiKey and X-Api-Key. Keys in filter_keys_with_hashes are
        # filtered too, with a hash of their value.
        [filters.filter_keys, filters.filter_keys_with_hashes].each do |keys|
          return true if keys.include?(normalized_key.downcase.to_sym) || keys.include?(words)
        end

        matched = filters.filter_matchers.any? do |matcher|
          next false if logstruct_field && !matcher.matches_logstruct_fields

          matcher.matches?(normalized_key, value)
        rescue => e
          handle_filter_matcher_error(e, matcher.label, normalized_key)
          # An unsuccessful filter must never expose the value it was meant to protect.
          true
        end
        return true if matched
        return false if filters.path_matchers.empty?

        path ||= [normalized_key]
        root = {} if root.nil?
        filters.path_matchers.any? do |matcher|
          matcher.matches?(path, value, root)
        rescue => e
          handle_filter_matcher_error(e, matcher.label, normalized_key)
          true
        end
      end

      # Check if a key should be hashed rather than completely filtered
      sig { params(key: T.untyped).returns(T::Boolean) }
      def should_include_string_hash?(key)
        keys = LogStruct.config.filters.filter_keys_with_hashes
        keys.include?(key.to_s.downcase.to_sym) || keys.include?(KeyWords.normalize(key.to_s).to_sym)
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
        filtered_string[:_hash] = StringScrubber.value_hash(string) if include_hash

        filtered_string
      end

      # Summarize a filtered Hash: its first 10 keys and how many there are. No size, which would say
      # how long the secrets in it are.
      sig { params(hash: T::Hash[T.untyped, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def summarize_hash(hash)
        return {_class: "Hash", _empty: true} if hash.empty?

        {
          _class: Hash,
          _keys_count: hash.size,
          _keys: hash.each_key.take(10).map { |key| normalize_summary_key(StringScrubber.scrub_name(key)) }
        }
      end

      # Summarize a filtered Array: how many items it has
      sig { params(array: T::Array[T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def summarize_array(array)
        return {_class: "Array", _empty: true} if array.empty?

        {
          _class: Array,
          _count: array.size
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
