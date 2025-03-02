# typed: strict
# frozen_string_literal: true

module LogStruct
  # This class contains methods for filtering sensitive data in logs
  # It is used by JSONFormatter to determine which keys should be filtered
  class ParamFilters
    class << self
      extend T::Sig

      # Check if a key should be filtered based on our defined sensitive keys
      sig { params(key: T.any(String, Symbol)).returns(T::Boolean) }
      def should_filter_key?(key)
        LogStruct.configuration.filtered_keys.include?(key.to_s.downcase.to_sym)
      end

      # Create a simple summary of JSON data for logging
      sig { params(data: T.untyped).returns(T::Hash[Symbol, T.untyped]) }
      def summarize_json_attribute(data)
        case data
        when Hash
          summarize_hash(data)
        when Array
          summarize_array(data)
        else
          {_class: data.class.to_s}
        end
      end

      # Summarize a hash for logging
      sig { params(hash: T::Hash[T.untyped, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def summarize_hash(hash)
        return {_class: "Hash", _empty: true} if hash.empty?

        {
          _class: "Hash",
          _keys_count: hash.keys.size,
          _keys: hash.keys.map(&:to_sym).take(10),
          _bytes: hash.to_json.size
        }
      end

      # Summarize an array for logging
      sig { params(array: T::Array[T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def summarize_array(array)
        return {_class: "Array", _empty: true} if array.empty?

        {
          _class: "Array",
          _count: array.size,
          _bytes: array.to_json.size
        }
      end
    end
  end
end
