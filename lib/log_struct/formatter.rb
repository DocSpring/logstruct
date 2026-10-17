# typed: strict
# frozen_string_literal: true

require "logger"
require "active_support/core_ext/object/blank"
require "active_support/hash_with_indifferent_access"
require "json"
require "globalid"
require_relative "enums/source"
require_relative "enums/event"
require_relative "enums/log_field"
require_relative "string_scrubber"
require_relative "log"
require_relative "param_filters"
require_relative "multi_error_reporter"

module LogStruct
  class Formatter < ::Logger::Formatter
    extend T::Sig

    # Add current_tags method to support ActiveSupport::TaggedLogging
    sig { returns(T::Array[String]) }
    def current_tags
      Thread.current[:activesupport_tagged_logging_tags] ||= []
    end

    # Add tagged method to support ActiveSupport::TaggedLogging
    sig { params(tags: T::Array[String], blk: T.proc.params(formatter: Formatter).void).returns(T.untyped) }
    def tagged(*tags, &blk)
      new_tags = tags.flatten
      current_tags.concat(new_tags) if new_tags.any?
      yield self
    ensure
      current_tags.pop(new_tags.size) if new_tags&.any?
    end

    # Add clear_tags! method to support ActiveSupport::TaggedLogging
    sig { void }
    def clear_tags!
      Thread.current[:activesupport_tagged_logging_tags] = []
    end

    sig { params(tags: T::Array[String]).returns(T.untyped) }
    def push_tags(*tags)
      current_tags.concat(tags)
    end

    sig { params(string: String).returns(String) }
    def scrub_string(string)
      # Use StringScrubber module to scrub sensitive information from strings
      StringScrubber.scrub(string)
    end

    MAX_RECURSION_DEPTH = 20

    # The mask Rails' parameter filter puts in place of filtered values
    RAILS_FILTERED_MASK = "[FILTERED]"

    # LogStruct's own fields, which some filters don't apply to at the top of a line
    LOG_FIELD_KEYS = T.let(LogField.values.map(&:serialize).to_set.freeze, T::Set[T.untyped])

    # path and root are for filters that match a key by its path (see ParamFilters.should_filter_key?).
    # They're only tracked when such filters exist: path is nil otherwise.
    sig do
      params(
        arg: T.untyped,
        recursion_depth: Integer,
        ancestors: T::Hash[T.untyped, T::Boolean],
        path: T.nilable(T::Array[String]),
        root: T.untyped
      ).returns(T.untyped)
    end
    def process_values(arg, recursion_depth: 0, ancestors: {}.compare_by_identity, path: nil, root: nil)
      if recursion_depth == 0 && path.nil? && !LogStruct.config.filters.path_matchers.empty?
        path = []
      end

      # Circular references and deeply nested values stop here. Values below this depth
      # would skip filtering and scrubbing, so they're summarized instead of logged.
      return summarize_unprocessed_value(arg) if recursion_depth > MAX_RECURSION_DEPTH || ancestors.key?(arg)

      case arg
      when Hash, Array
        ancestors[arg] = true
        begin
          if arg.is_a?(Hash)
            process_hash(arg, recursion_depth: recursion_depth, ancestors: ancestors, path: path, root: root)
          else
            process_array(arg, recursion_depth: recursion_depth, ancestors: ancestors, path: path, root: root)
          end
        ensure
          ancestors.delete(arg)
        end
      when GlobalID::Identification
        # Scrubbed like any String: a record's ID can be an email address
        begin
          scrub_string(arg.to_global_id.to_s)
        rescue
          begin
            object = T.cast(arg, Object)
            # Active Record is optional
            if defined?(::ActiveRecord::Base) && object.is_a?(::ActiveRecord::Base)
              scrub_string("#{object.class}(##{object.id})")
            else
              # For non-ActiveRecord objects that failed to_global_id, try to get a string representation
              # If this also fails, we want to catch it and return the error placeholder
              scrub_string(String(object))
            end
          rescue => e
            LogStruct.handle_exception(e, source: Source::Internal)
            "[GLOBALID_ERROR]"
          end
        end
      when Source, Event
        arg.serialize
      when String
        scrub_string(arg)
      when Time
        arg.iso8601(3)
      when Symbol
        StringScrubber.scrub_name(arg)
      when Numeric, TrueClass, FalseClass, NilClass
        arg
      else
        # Structs, ActionController::Parameters and other objects: filter and scrub what
        # to_json would write
        process_values(arg.as_json, recursion_depth: recursion_depth + 1, ancestors: ancestors, path: path, root: root)
      end
    rescue => e
      # Report error through LogStruct's framework
      context = {
        processor_method: "process_values",
        value_type: arg.class.name,
        recursion_depth: recursion_depth
      }
      LogStruct.handle_exception(e, source: Source::Internal, context: context)
      summarize_unprocessed_value(arg)
    end

    sig do
      params(
        hash: T::Hash[T.untyped, T.untyped],
        recursion_depth: Integer,
        ancestors: T::Hash[T.untyped, T::Boolean],
        path: T.nilable(T::Array[String]),
        root: T.untyped
      ).returns(T::Hash[T.untyped, T.untyped])
    end
    def process_hash(hash, recursion_depth:, ancestors:, path: nil, root: nil)
      result = {}

      # Rails gives filter blocks the request's parameters with indifferent access
      line_root = (path && recursion_depth == 0) ? with_indifferent_access(hash) : nil

      hash.each do |key, value|
        logstruct_field = recursion_depth == 0 && LOG_FIELD_KEYS.include?(key)
        key_path = path && [*path, key.to_s]
        # A top-level key's root is the line; the keys below it get the top-level field's value
        key_root = (recursion_depth == 0) ? line_root : root
        children_root = (path && recursion_depth == 0) ? with_indifferent_access(value) : root
        # Check if this key should be filtered at any depth
        filtered = ParamFilters.should_filter_key?(key, value, logstruct_field: logstruct_field, path: key_path, root: key_root)
        # Keys are scrubbed too: an email address can be a key
        result[StringScrubber.scrub_name(key)] = if !filtered
          process_values(value, recursion_depth: recursion_depth + 1, ancestors: ancestors, path: key_path, root: children_root)
        elsif value == RAILS_FILTERED_MASK
          # Rails' parameter filter has already replaced the value
          value
        else
          {_filtered: ParamFilters.summarize_json_attribute(key, value)}
        end
      end

      result
    end

    sig { params(value: T.untyped).returns(T.untyped) }
    def with_indifferent_access(value)
      value.is_a?(Hash) ? ActiveSupport::HashWithIndifferentAccess.new(value) : value
    rescue SystemStackError, StandardError
      value
    end

    # Like deep_symbolize_keys, but stops at circular references and at the depth where
    # process_values stops, leaving those values for process_values to summarize
    sig { params(value: T.untyped, recursion_depth: Integer, ancestors: T::Hash[T.untyped, T::Boolean]).returns(T.untyped) }
    def symbolize_keys(value, recursion_depth: 0, ancestors: {}.compare_by_identity)
      return value if recursion_depth > MAX_RECURSION_DEPTH || ancestors.key?(value)

      case value
      when Hash
        ancestors[value] = true
        result = value.each_with_object({}) do |(key, nested_value), symbolized|
          symbol_key = key.respond_to?(:to_sym) ? key.to_sym : key
          symbolized[symbol_key] = symbolize_keys(nested_value, recursion_depth: recursion_depth + 1, ancestors: ancestors)
        end
        ancestors.delete(value)
        result
      when Array
        ancestors[value] = true
        result = value.map { |item| symbolize_keys(item, recursion_depth: recursion_depth + 1, ancestors: ancestors) }
        ancestors.delete(value)
        result
      else
        value
      end
    end

    # Describes a value without filtering, scrubbing or serializing it, so that values which
    # couldn't be processed are never logged raw. Hashes and arrays are not serialized because
    # they may contain circular references.
    sig { params(arg: T.untyped).returns(T.untyped) }
    def summarize_unprocessed_value(arg)
      case arg
      when Hash
        {_filtered: {_class: arg.class.name, _keys_count: arg.size}}
      when Array
        {_filtered: {_class: arg.class.name, _count: arg.size}}
      when String
        {_filtered: {_class: arg.class.name, _bytes: arg.bytesize}}
      when Numeric, Symbol, TrueClass, FalseClass, NilClass
        arg
      else
        {_filtered: {_class: arg.class.name}}
      end
    end

    sig { params(log_value: T.untyped, time: Time).returns(T::Hash[Symbol, T.untyped]) }
    def log_value_to_hash(log_value, time:)
      case log_value
      when Log::Interfaces::CommonFields
        # Our log classes all implement a custom #serialize method that use symbol keys
        log_value.serialize

      when T::Struct
        # Default T::Struct.serialize methods returns a hash with string keys, so convert them to symbols
        symbolize_keys(log_value.serialize)

      when Hash
        # Use hash as is and convert string keys to symbols
        symbolize_keys(log_value)

      else
        # Create a Plain log with the message as a string and serialize it with symbol keys
        # log_value can be literally anything: Integer, Float, Boolean, NilClass, etc.
        log_message = case log_value
        # Handle all the basic types without any further processing
        when String, Symbol, TrueClass, FalseClass, NilClass, Array, Hash, Time, Numeric
          log_value
        else
          # Handle the serialization of complex objects in a useful way:
          #
          # 1. For ActiveRecord models: Use as_json which includes attributes
          # 2. For objects with custom as_json implementations: Use their implementation
          # 3. For basic objects that only have ActiveSupport's as_json: Use to_s
          begin
            method_owner = log_value.method(:as_json).owner

            # If it's ActiveRecord, ActiveModel, or a custom implementation, use as_json
            if method_owner.to_s.include?("ActiveRecord") ||
                method_owner.to_s.include?("ActiveModel") ||
                method_owner.to_s.exclude?("ActiveSupport::CoreExtensions") &&
                    method_owner.to_s.exclude?("Object")
              log_value.as_json
            else
              # For plain objects with only the default ActiveSupport as_json
              log_value.to_s
            end
          rescue => e
            # Handle serialization errors
            context = {
              object_class: log_value.class.name,
              object_inspect: log_value.inspect.truncate(100)
            }
            LogStruct.handle_exception(e, source: Source::Internal, context: context)

            # Fall back to the string representation to ensure we continue processing
            log_value.to_s
          end
        end

        Log::Plain.new(
          message: log_message,
          timestamp: time
        ).serialize
      end
    end

    # Serializes Log (or string) into JSON
    sig { params(severity: T.any(String, Symbol, Integer), time: Time, progname: T.nilable(String), log_value: T.untyped).returns(String) }
    def call(severity, time, progname, log_value)
      level_enum = Level.from_severity(severity)

      data = log_value_to_hash(log_value, time: time)

      # Filter params, scrub sensitive values, format ActiveJob GlobalID arguments
      data = process_values(data)

      # Add standard fields if not already present
      data[:src] ||= Source::App
      data[:evt] ||= Event::Log
      data[:ts] ||= time.iso8601(3)
      data[:lvl] = level_enum # Set level from severity parameter
      data[:prog] = progname if progname.present?
      request_id = Thread.current[:logstruct_request_id]
      if request_id.is_a?(String) && !request_id.empty? && !data.key?(:req_id)
        data[:req_id] = request_id
      end

      generate_json(data)
    end

    # Output as JSON with a newline. We mock this method in tests so we can
    # inspect the data right before it gets turned into a JSON string.
    sig { params(data: T::Hash[T.untyped, T.untyped]).returns(String) }
    def generate_json(data)
      "#{data.to_json}\n"
    end

    # An array's items keep the array's path, as in Rails (users.name filters each user's name)
    sig do
      params(
        array: T::Array[T.untyped],
        recursion_depth: Integer,
        ancestors: T::Hash[T.untyped, T::Boolean],
        path: T.nilable(T::Array[String]),
        root: T.untyped
      ).returns(T::Array[T.untyped])
    end
    def process_array(array, recursion_depth:, ancestors:, path: nil, root: nil)
      return [] if array.empty?

      if looks_like_backtrace_array?(array)
        array.map { |value| process_values(value, recursion_depth: recursion_depth + 1, ancestors: ancestors, path: path, root: root) }
      else
        processed = []
        array.each_with_index do |value, index|
          break if index >= 10

          processed << process_values(value, recursion_depth: recursion_depth + 1, ancestors: ancestors, path: path, root: root)
        end

        if array.size > 10
          processed << "... and #{array.size - 10} more items"
        end

        processed
      end
    end

    # Check if an array looks like a backtrace (array of strings with file:line pattern)
    sig { params(array: T::Array[T.untyped]).returns(T::Boolean) }
    def looks_like_backtrace_array?(array)
      backtrace_like_count = array.first(5).count do |element|
        element.is_a?(String) && element.match?(/\A[^:\s]+:\d+/)
      end

      backtrace_like_count >= 3
    end
  end
end
