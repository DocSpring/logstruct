# typed: true
# frozen_string_literal: true

module LogStruct
  # This class contains configuration for filtering sensitive data in logs
  # It is used by JSONFormatter to determine which keys should be filtered
  class ParamFilters
    class << self
      attr_accessor :filtered_keys, :filtered_json_columns, :ignored_json_columns, :ignored_tables

      # Initialize default configuration
      def configure
        # Default sensitive keys that should always be filtered
        @filtered_keys = %i[
          password password_confirmation token secret
          credentials auth authentication authorization
          credit_card ssn social_security
        ].freeze

        # JSON/JSONB columns that should be filtered from logs
        # These are columns that might contain sensitive or large data
        # Format: { model_name => [columns_to_filter] }
        @filtered_json_columns = {}.freeze

        # JSON/JSONB columns that should be excluded from filtering
        # These are columns that don't need filtering (e.g., attachment data)
        # Format: { model_name => [columns_to_exclude] }
        @ignored_json_columns = {}.freeze

        # Tables to exclude entirely from JSON column filtering
        @ignored_tables = [].freeze

        # Allow custom configuration
        yield(self) if block_given?

        # Cache the flattened list of columns to filter for performance
        @all_columns_to_filter = @filtered_json_columns.values.flatten.sort.uniq.freeze
      end

      # Check if a key should be filtered based on our defined sensitive keys
      def should_filter_key?(key)
        @filtered_keys.include?(key.to_s.downcase.to_sym)
      end

      # Check if a key should be filtered based on our defined column names
      # This method is called with the key name, not the data itself
      def should_filter_json_data?(key)
        # Check if the key matches any of our columns to filter
        @all_columns_to_filter.include?(key.to_sym)
      end

      # Create a simple summary of JSON data for logging
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
      def summarize_hash(hash)
        return {_class: "Hash", _empty: true} if hash.empty?

        {
          _class: "Hash",
          _bytes: hash.to_json.size,
          _keys: hash.keys.map(&:to_sym).take(10),
          _keys_count: hash.keys.size
        }
      end

      # Summarize an array for logging
      def summarize_array(array)
        return {_class: "Array", _empty: true} if array.empty?

        {
          _class: "Array",
          _count: array.size,
          _bytes: array.to_json.size
        }
      end
    end

    # Initialize with default configuration
    configure
  end
end
