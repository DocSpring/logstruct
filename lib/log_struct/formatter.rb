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
require_relative "bounded_input"
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
      when Hash, Array, ::ActionController::Parameters
        ancestors[arg] = true
        begin
          if arg.is_a?(Array)
            process_array(arg, recursion_depth: recursion_depth, ancestors: ancestors, path: path, root: root)
          else
            process_hash(arg, recursion_depth: recursion_depth, ancestors: ancestors, path: path, root: root)
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
            LogStruct.handle_value_error(e, "GlobalID formatting failed")
            "[GLOBALID_ERROR]"
          end
        end
      when Source, Event
        arg.serialize
      when String
        scrub_limited_string(valid_utf8(arg))
      when Time
        arg.iso8601(3)
      when Symbol
        StringScrubber.scrub_name(arg)
      when Float
        # JSON has no NaN or Infinity
        arg.finite? ? arg : arg.to_s
      when Numeric, TrueClass, FalseClass, NilClass
        arg
      else
        # Structs and other objects: filter and scrub what
        # to_json would write
        process_values(arg.as_json, recursion_depth: recursion_depth + 1, ancestors: ancestors, path: path, root: root)
      end
    rescue SystemStackError, StandardError => e
      # A SystemStackError comes from an object whose as_json refers back to itself
      context = {
        processor_method: "process_values",
        value_type: arg.class.name,
        recursion_depth: recursion_depth
      }
      LogStruct.handle_value_error(e, "value formatting failed", context: context)
      summarize_unprocessed_value(arg)
    end

    sig do
      params(
        hash: T.untyped,
        recursion_depth: Integer,
        ancestors: T::Hash[T.untyped, T::Boolean],
        path: T.nilable(T::Array[String]),
        root: T.untyped
      ).returns(T::Hash[T.untyped, T.untyped])
    end
    def process_hash(hash, recursion_depth:, ancestors:, path: nil, root: nil)
      result = {}

      # Path matchers' roots are built only if a matcher reads them (most don't)
      line_root = (path && recursion_depth == 0) ? ConfigStruct::LazyRoot.new(hash) : nil

      max_keys = LogStruct.config.limits.max_hash_keys
      max_key_bytes = LogStruct.config.limits.max_string_bytes
      oversized_keys = 0
      hash.each_pair.with_index do |(key, value), index|
        if index >= max_keys
          result[:_more_keys] = BoundedInput.key_count(hash) - max_keys
          break
        end

        if BoundedInput::COUNT_KEYS.include?(key) && value.is_a?(Integer)
          result[key] = value
          next
        end

        if key.to_s.bytesize > max_key_bytes
          oversized_keys += 1
          next
        end

        # Checked again: each byte that isn't valid UTF-8 becomes a 3-byte U+FFFD
        key = valid_utf8_key(key)
        if key.to_s.bytesize > max_key_bytes
          oversized_keys += 1
          next
        end
        logstruct_field = recursion_depth == 0 && LOG_FIELD_KEYS.include?(key)
        key_path = path && [*path, key.to_s]
        # A top-level key's root is the line; the keys below it get the top-level field's value
        key_root = (recursion_depth == 0) ? line_root : root
        children_root = (path && recursion_depth == 0) ? ConfigStruct::LazyRoot.new(value) : root
        # Check if this key should be filtered at any depth
        filtered = ParamFilters.should_filter_key?(key, value, logstruct_field: logstruct_field, path: key_path, root: key_root)
        # Keys are scrubbed too: an email address can be a key
        scrubbed_key = StringScrubber.scrub_name(key)
        scrubbed_key = scrub_limited_string(scrubbed_key) if scrubbed_key.is_a?(String) && scrubbed_key.bytesize > max_key_bytes
        result[scrubbed_key] = if !filtered
          process_values(value, recursion_depth: recursion_depth + 1, ancestors: ancestors, path: key_path, root: children_root)
        elsif value == RAILS_FILTERED_MASK
          # Rails' parameter filter has already replaced the value
          value
        else
          {_filtered: ParamFilters.summarize_json_attribute(key, value)}
        end
      end

      result[:_oversized_keys] = oversized_keys if oversized_keys.positive?

      result
    end

    # The string as valid UTF-8. JSON can't hold other bytes: Puma passes headers as binary
    # strings, and a byte like \xFF in a User-Agent would stop the whole line from being written.
    # Bytes that aren't valid UTF-8 become U+FFFD.
    sig { params(string: String).returns(String) }
    def valid_utf8(string)
      StringScrubber.valid_utf8(string)
    end

    # Normalize only keys that will be logged, after applying the size limits.
    sig { params(key: T.untyped).returns(T.untyped) }
    def valid_utf8_key(key)
      case key
      when String
        valid_utf8(key).to_sym
      when Symbol
        name = key.name
        fixed = valid_utf8(name)
        fixed.equal?(name) ? key : fixed.to_sym
      else
        valid_utf8(key.to_s)
      end
    end

    # The scrubbers see a little more than a cut string keeps, so data at the cut is scrubbed whole
    SCRUB_MARGIN_BYTES = 256

    # A string scrubbed, and cut to limits.max_string_bytes. The scrubbers see its first max_string_bytes plus
    # SCRUB_MARGIN_BYTES: a value running past that was only partly seen, so scrub_cut_end replaces it if it can
    # be a credential.
    sig { params(string: String).returns(String) }
    def scrub_limited_string(string)
      max_bytes = LogStruct.config.limits.max_string_bytes
      return scrub_string(string) if string.bytesize <= max_bytes

      seen_bytes = max_bytes + SCRUB_MARGIN_BYTES
      scrubbed = scrub_string(string.byteslice(0, seen_bytes).to_s.scrub(""))
      if string.bytesize > seen_bytes
        scrubbed = StringScrubber.scrub_cut_end(scrubbed)
      elsif scrubbed.bytesize <= max_bytes
        # The scrubbers saw all of it, and their replacements made it short enough
        return scrubbed
      end
      kept = scrubbed.byteslice(0, max_bytes).to_s.scrub("")
      "#{kept}... (cut from #{string.bytesize} bytes)"
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
      when String, Symbol
        {_filtered: {_class: arg.class.name}}
      when Numeric, TrueClass, FalseClass, NilClass
        arg
      else
        {_filtered: {_class: arg.class.name}}
      end
    end

    sig { params(log_value: T.untyped, time: Time).returns(T::Hash[T.untyped, T.untyped]) }
    def log_value_to_hash(log_value, time:)
      case log_value
      when Log::Interfaces::CommonFields
        # Our log classes all implement a custom #serialize method that use symbol keys
        log_value.serialize

      when T::Struct
        log_value.serialize

      when Hash
        log_value

      when Exception
        # logger.error(exception): its class, message and backtrace
        Log.from_exception(Source::App, log_value, {}, time).serialize

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
            LogStruct.handle_value_error(e, "value serialization failed", context: {object_class: log_value.class.name})

            # An object's string representation may contain the same secret that broke serialization.
            "[SERIALIZATION_ERROR]"
          end
        end

        Log::Plain.new(
          message: log_message,
          timestamp: time
        ).serialize
      end
    end

    # Serializes Log (or string) into JSON.
    # request_id: the request's ID (default: the one RequestContext stored for this thread).
    # context: fields for the line's ctx, like the running job's ID and class. The line's own ctx keys win.
    # tags: the logger's tags (logger.tagged("billing")), written as tags unless the line has its own.
    sig do
      params(
        severity: T.any(String, Symbol, Integer),
        time: Time,
        progname: T.nilable(String),
        log_value: T.untyped,
        request_id: T.nilable(String),
        context: T.nilable(T::Hash[T.untyped, T.untyped]),
        tags: T.nilable(T::Array[T.untyped])
      ).returns(String)
    end
    def call(severity, time, progname, log_value, request_id: nil, context: nil, tags: nil)
      previous_internal_error = Thread.current[:logstruct_formatting_internal_error]
      level_enum = Level.from_severity(severity)

      data = log_value_to_hash(log_value, time: time)
      source = data[:src] || data["src"]
      event = data[:evt] || data["evt"]
      if [Source::Internal, :logstruct, "logstruct"].include?(source) && [Event::Error, :error, "error"].include?(event)
        Thread.current[:logstruct_formatting_internal_error] = true
      end

      # Filter params, scrub sensitive values, format ActiveJob GlobalID arguments
      data = process_values(data)

      # Add standard fields if not already present
      data[:src] ||= Source::App
      data[:evt] ||= Event::Log
      data[:ts] ||= time.iso8601(3)
      data[:lvl] = level_enum # Set level from severity parameter
      add_metadata(data, progname: progname, request_id: request_id || Thread.current[:logstruct_request_id], context: context, tags: tags)

      begin
        generate_json(data)
      rescue SystemStackError, StandardError => e
        unwritable_line_json(data, e)
      end
    ensure
      Thread.current[:logstruct_formatting_internal_error] = previous_internal_error
    end

    # A line that can't be written as JSON is replaced by one that says so, instead of being lost
    sig { params(data: T::Hash[T.untyped, T.untyped], error: Exception).returns(String) }
    def unwritable_line_json(data, error)
      level = data[:lvl]
      line = {
        src: enum_or_string(data[:src]) || Source::Internal.serialize,
        evt: enum_or_string(data[:evt]) || Event::Error.serialize,
        ts: data[:ts].is_a?(String) ? data[:ts] : Time.now.iso8601(3),
        lvl: level.is_a?(Level) ? level.serialize : Level::Error.serialize,
        msg: "LogStruct couldn't write this line as JSON",
        error_class: error.class.name
      }
      unless Thread.current[:logstruct_reporting_unwritable_line]
        begin
          Thread.current[:logstruct_reporting_unwritable_line] = true
          reported = error.is_a?(StandardError) ? error : RuntimeError.new("#{error.class}: #{error.message}")
          LogStruct.handle_exception(reported, source: Source::Internal, context: {src: line[:src], evt: line[:evt]})
        ensure
          Thread.current[:logstruct_reporting_unwritable_line] = nil
        end
      end
      "#{::JSON.generate(line)}\n"
    end

    # The program name, request ID and job context, filtered and scrubbed like the rest of the line:
    # an X-Request-Id header can carry anything
    sig do
      params(
        data: T::Hash[T.untyped, T.untyped],
        progname: T.nilable(String),
        request_id: T.untyped,
        context: T.nilable(T::Hash[T.untyped, T.untyped]),
        tags: T.nilable(T::Array[T.untyped])
      ).void
    end
    def add_metadata(data, progname:, request_id:, context:, tags:)
      metadata = {}
      metadata[:prog] = progname if progname.present?
      metadata[:tags] = tags if tags.is_a?(Array) && !tags.empty? && !data.key?(:tags)
      if request_id.is_a?(String) && !request_id.empty? && !data.key?(:req_id)
        metadata[:req_id] = request_id
      end
      metadata[:ctx] = context if context.present?
      return if metadata.empty?

      processed = process_values(metadata)
      job_context = processed.delete(:ctx)
      data.merge!(processed)
      return if job_context.nil?

      line_context = data[:ctx]
      # A logged Hash's own ctx keeps its keys and gains the job's
      data[:ctx] = line_context.is_a?(Hash) ? job_context.merge(line_context) : (line_context || job_context)
    end

    sig { params(value: T.untyped).returns(T.nilable(String)) }
    def enum_or_string(value)
      if value.is_a?(Source) || value.is_a?(Event)
        value.serialize.to_s
      elsif value.is_a?(String)
        value
      end
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

      limits = LogStruct.config.limits
      backtrace = looks_like_backtrace_array?(array)
      max_items = backtrace ? limits.max_backtrace_lines : limits.max_array_items
      processed = array.first(max_items).map do |value|
        process_values(value, recursion_depth: recursion_depth + 1, ancestors: ancestors, path: path, root: root)
      end
      if array.size > max_items
        processed << "... and #{array.size - max_items} more #{backtrace ? "lines" : "items"}"
      end

      processed
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
