# typed: false
# frozen_string_literal: true

require "test_helper"

module LogStruct
  class FormatterTest < ActiveSupport::TestCase
    def setup
      @formatter = Formatter.new
      @severity = ::Logger::INFO
      @time = Time.utc(2023, 1, 1, 12, 0, 0)
      @progname = "test"
      @iso_time = "2023-01-01T12:00:00.000Z"

      # Clean up tags before each test
      Thread.current[:activesupport_tagged_logging_tags] = nil
    end

    def teardown
      # Clean up after tests
      Thread.current[:activesupport_tagged_logging_tags] = nil
    end

    def test_call_with_string_message
      message = "Test message"
      result = JSON.parse(@formatter.call(@severity, @time, @progname, message))

      assert_equal message, result["msg"]
      assert_equal "app", result["src"]
      assert_equal "log", result["evt"]
      assert_equal @iso_time, result["ts"]
      assert_equal "info", result["lvl"]
      assert_equal @progname, result["prog"]
    end

    def test_call_applies_string_scrubber_to_message
      # Use real StringScrubber scrubbing
      email_message = "Email: user@example.com"
      result = JSON.parse(@formatter.call(@severity, @time, @progname, email_message))

      assert_not_includes result["msg"], "user@example.com"
    end

    def test_call_with_struct_serializes_properly
      # Create a proper T::Struct log entry
      log_entry = LogStruct::Log::Plain.new(
        message: "Test message",
        source: LogStruct::Source::App
      )

      result = JSON.parse(@formatter.call(@severity, @time, @progname, log_entry))

      assert_equal "Test message", result["msg"]
      assert_equal "app", result["src"]
      assert_equal "log", result["evt"]
      assert_equal "info", result["lvl"]
    end

    def test_formats_active_job_arguments_with_global_ids
      user_class = create_user_class
      user = user_class.new(123)

      message = {
        source: "active_job",
        arguments: [user, {email: "test@example.com"}]
      }

      result = JSON.parse(@formatter.call(@severity, @time, @progname, message))

      assert_equal "gid://logstruct/User/123", result["arguments"][0]
      assert_not_includes result["arguments"][1]["email"], "test@example.com"
    end

    def test_handles_global_id_errors_gracefully
      # For this test, we'll directly test the GlobalID error handling section
      # by stubbing out the process_values method for a specific object

      # Create a special class inside this test method
      my_gid_class = Class.new do
        include GlobalID::Identification

        def to_global_id
          raise StandardError, "Can't serialize"
        end

        # In Rails 8.0+, ensure any fallback methods also raise to trigger error path
        def inspect
          raise StandardError, "Can't inspect"
        end

        def to_s
          raise StandardError, "Can't stringify"
        end
      end

      # Create an instance of it
      error_obj = my_gid_class.new

      # Need to stub LogStruct.handle_exception to avoid actually reporting an error
      LogStruct.stub(:handle_exception, nil) do
        # Test the error handling path in process_values
        result = @formatter.process_values(error_obj)

        assert_equal "[GLOBALID_ERROR]", result
      end
    end

    def test_tagged_logging_support
      # Test current_tags
      assert_empty @formatter.current_tags
      Thread.current[:activesupport_tagged_logging_tags] = %w[tag1 tag2]

      assert_equal %w[tag1 tag2], @formatter.current_tags
    end

    def test_tagged_method
      # Give the result variable a specific type
      result = T.let(nil, T.nilable(LogStruct::Formatter))

      @formatter.tagged(["tag1", "tag2"]) do |f|
        assert_equal %w[tag1 tag2], f.current_tags
        result = f
      end

      assert_empty @formatter.current_tags
      assert_equal @formatter, result
    end

    def test_clear_tags
      Thread.current[:activesupport_tagged_logging_tags] = %w[tag1 tag2]
      @formatter.clear_tags!

      assert_empty @formatter.current_tags
    end

    def test_process_values_formats_global_id_objects
      user_class = create_user_class
      user = user_class.new(123)

      result = @formatter.process_values(user)

      assert_equal "gid://logstruct/User/123", result
    end

    def test_process_values_scrubs_global_ids
      user_class = create_user_class
      user = user_class.new("ada@example.com")

      result = @formatter.process_values(user)

      assert_match %r{\Agid://logstruct/User/\[EMAIL:[a-f0-9]+\]\z}, result
    end

    def test_scrubs_keys_and_symbol_values
      result = @formatter.process_values({"ada@example.com" => {status: :"bob@example.com"}, :level => :info})

      assert_equal :info, result[:level]
      key = result.keys.first

      assert_match(/\A\[EMAIL:[a-f0-9]+\]\z/, key)
      assert_match(/\A\[EMAIL:[a-f0-9]+\]\z/, result.dig(key, :status))
    end

    def test_scrubs_the_keys_of_filtered_hashes
      log_line = @formatter.call(@severity, @time, @progname, {msg: "tokens", tokens: {"ada@example.com" => "t1"}})

      assert_not_includes log_line, "ada@example.com"
      assert_match(/\[EMAIL:[a-f0-9]+\]/, JSON.parse(log_line).dig("tokens", "_filtered", "_keys", 0))
    end

    def test_process_values_formats_hashes_recursively
      user_class = create_user_class
      user = user_class.new(123)
      arg = {user: user, data: {value: "test"}}

      result = @formatter.process_values(arg)

      assert_equal "gid://logstruct/User/123", result[:user]
      assert_equal "test", result[:data][:value]
    end

    def test_process_values_formats_arrays_recursively
      user_class = create_user_class
      user = user_class.new(123)
      arg = [user, {email: "test@example.com"}]

      result = @formatter.process_values(arg)

      assert_equal "gid://logstruct/User/123", result[0]
      assert_not_includes result[1][:email], "test@example.com"
    end

    def test_process_values_truncates_large_arrays
      arg = (1..20).to_a
      result = @formatter.process_values(arg)

      assert_equal 11, result.length
      assert_equal "... and 10 more items", result.last
    end

    def test_process_values_does_not_process_beyond_limit_for_large_arrays
      exploding_class = Class.new do
        attr_reader :index

        def initialize(index, raise_on_touch)
          @index = index
          @raise_on_touch = raise_on_touch
        end

        def touch!
          raise "Should not touch index #{@index}" if @raise_on_touch
        end
      end

      counting_formatter = Class.new(Formatter) do
        attr_reader :touched_indices

        def initialize
          super
          @touched_indices = []
        end

        def process_values(value, **options)
          if value.respond_to?(:touch!)
            value.touch!
            @touched_indices << value.index if value.respond_to?(:index)
          end

          super
        end
      end.new

      values = (0...10).map { |i| exploding_class.new(i, false) } +
        (10...20).map { |i| exploding_class.new(i, true) }

      result = counting_formatter.process_values(values)

      assert_equal 11, result.length
      assert_equal((0...10).to_a, counting_formatter.touched_indices)
    end

    def test_process_values_handles_recursive_structures
      hash1 = {a: 1}
      hash2 = {b: 2, hash1: hash1}
      hash1[:hash2] = hash2 # Create a circular reference

      # This should not cause an infinite recursion
      result = @formatter.process_values(hash1)

      assert_instance_of Hash, result
      assert_equal 1, result[:a]
      assert_equal 2, result[:hash2][:b]
    end

    def test_filters_and_scrubs_values_nested_past_the_depth_limit
      deep = {password: "hunter2", note: "a@b.com", items: [1, 2, 3]}
      22.times { deep = {n: deep} }

      log_line = @formatter.call(@severity, @time, @progname, {msg: "deep", ctx: deep})

      assert_not_includes log_line, "hunter2"
      assert_not_includes log_line, "a@b.com"
      JSON.parse(log_line)
    end

    def test_summarizes_each_type_past_the_depth_limit
      too_deep = 21

      assert_equal({_filtered: {_class: "Hash", _keys_count: 2}},
        @formatter.process_values({a: 1, b: 2}, recursion_depth: too_deep))
      assert_equal({_filtered: {_class: "Array", _count: 3}},
        @formatter.process_values([1, 2, 3], recursion_depth: too_deep))
      assert_equal({_filtered: {_class: "String"}},
        @formatter.process_values("a@b.com", recursion_depth: too_deep))
      assert_equal 42, @formatter.process_values(42, recursion_depth: too_deep)
      assert_nil @formatter.process_values(nil, recursion_depth: too_deep)
    end

    def test_logs_circular_hashes_without_raising
      circular = {name: "loop"}
      circular[:self] = circular

      log_line = @formatter.call(@severity, @time, @progname, {msg: "circular", ctx: circular})

      assert_equal "loop", JSON.parse(log_line).dig("ctx", "name")
    end

    def test_logs_hashes_with_several_back_references_once
      circular = {name: "loop"}
      circular[:first] = circular
      circular[:second] = circular

      log_line = @formatter.call(@severity, @time, @progname, {msg: "circular", ctx: circular})

      ctx = JSON.parse(log_line).fetch("ctx")

      assert_equal "loop", ctx["name"]
      assert_equal "loop", ctx.dig("first", "name")
      assert_equal({"_class" => "Hash", "_keys_count" => 3}, ctx.dig("first", "first", "_filtered"))
      assert_operator log_line.bytesize, :<, 1000
    end

    def test_summarizes_circular_values_under_filtered_keys
      circular_array = []
      circular_array << circular_array
      circular_hash = {name: "loop"}
      circular_hash[:self] = circular_hash

      log_line = @formatter.call(@severity, @time, @progname, {msg: "circular", password: circular_array, token: circular_hash})

      result = JSON.parse(log_line)

      assert_equal({"_class" => "Array", "_count" => 1}, result.dig("password", "_filtered"))
      assert_equal "Hash", result.dig("token", "_filtered", "_class")
      refute result.dig("token", "_filtered").key?("_bytes")
    end

    def test_filtered_summaries_leave_out_how_big_the_values_are
      log_line = @formatter.call(@severity, @time, @progname, {msg: "sizes", password: ["hunter2"], creds: {value: "hunter2"}})

      result = JSON.parse(log_line)

      assert_equal({"_class" => "Array", "_count" => 1}, result.dig("password", "_filtered"))
      assert_equal({"_class" => "Hash", "_keys_count" => 1, "_keys" => ["value"]}, result.dig("creds", "_filtered"))
    end

    def test_an_email_has_one_hash_under_a_key_and_in_text_however_its_written
      log_line = @formatter.call(@severity,
        @time,
        @progname,
        {msg: "Signed up User@Example.com", email: "user@example.com", note: "from USER@example.COM"})

      result = JSON.parse(log_line)
      email_hash = result.dig("email", "_filtered", "_hash")

      assert_match(/\A\h{12}\z/, email_hash)
      assert_equal "Signed up [EMAIL:#{email_hash}]", result["msg"]
      assert_equal "from [EMAIL:#{email_hash}]", result["note"]
    end

    def test_logs_a_value_shared_by_two_keys_in_full_each_time
      shared = {id: 1}

      result = @formatter.process_values({first: shared, second: shared})

      assert_equal({first: {id: 1}, second: {id: 1}}, result)
    end

    def test_filters_structs_parameters_and_other_objects
      login = Struct.new(:username, :password).new("alice", "hunter2")
      require "action_controller"
      params = ActionController::Parameters.new(password: "hunter2", name: "visible")
      account = Class.new {
        def initialize
          @api_token = "hunter2"
          @plan = "pro"
        end
      }.new

      log_line = @formatter.call(@severity,
        @time,
        @progname,
        {msg: "update", login: login, params: params, account: account})

      assert_not_includes log_line, "hunter2"
      result = JSON.parse(log_line)

      assert_equal "alice", result.dig("login", "username")
      assert_equal "visible", result.dig("params", "name")
      assert_equal "pro", result.dig("account", "plan")
    end

    def test_does_not_log_raw_values_when_processing_fails
      exploding_hash = Class.new(Hash) do
        def each(*)
          raise "boom"
        end
      end.new
      exploding_hash[:password] = "hunter2"

      LogStruct.stub(:handle_exception, nil) do
        result = @formatter.process_values(exploding_hash)

        assert_equal({_filtered: {_class: exploding_hash.class.name, _keys_count: 1}}, result)
      end
    end

    def test_keeps_values_rails_already_filtered
      result = @formatter.process_values({password: "[FILTERED]", secret_answer: "blue"})

      assert_equal "[FILTERED]", result[:password]
    end

    def test_generate_json
      data = {key: "value"}

      assert_equal "{\"key\":\"value\"}\n", @formatter.generate_json(data)
    end

    def test_log_value_to_hash_with_string
      # Test string conversion
      result = @formatter.log_value_to_hash("Test message", time: @time)

      assert_equal "Test message", result[:msg]
      assert result[:src]
      assert result[:ts]
    end

    def test_log_value_to_hash_with_hash
      # Test hash conversion (including string keys)
      result = @formatter.log_value_to_hash({
        "string_key" => "value",
        :symbol_key => "symbol_value"
      },
        time: @time)

      assert_equal "value", result[:string_key]
      assert_equal "symbol_value", result[:symbol_key]
    end

    def test_log_value_to_hash_with_struct
      # Test struct conversion
      log_entry = LogStruct::Log::Plain.new(
        message: "Struct message",
        source: LogStruct::Source::App
      )

      result = @formatter.log_value_to_hash(log_entry, time: @time)

      assert_equal "Struct message", result[:msg]
      assert_equal "app", result[:src]
    end

    def test_log_value_to_hash_with_other_types
      puts "Running test_log_value_to_hash_with_other_types"

      # Test numeric conversion
      number_result = @formatter.log_value_to_hash(123, time: @time)

      assert_equal 123, number_result[:msg]

      # Test boolean conversion
      bool_result = @formatter.log_value_to_hash(true, time: @time)

      assert bool_result[:msg]

      # Test object with as_json
      json_class = Class.new do
        def as_json
          {"name" => "JSON Object"}
        end
      end
      json_obj = json_class.new
      obj_result = @formatter.log_value_to_hash(json_obj, time: @time)

      assert_equal({"name" => "JSON Object"}, obj_result[:msg])

      # Test a normal Ruby object with a stable string representation
      test_obj = Class.new do
        def to_s
          "TestObject"
        end
      end.new

      # Just call the method normally
      obj_result = @formatter.log_value_to_hash(test_obj, time: @time)

      assert_equal "TestObject", obj_result[:msg]
    end

    def test_prevents_infinite_recursion_when_error_occurs
      # Create an object that will cause an infinite loop when processed
      problematic_object = Minitest::Mock.new
      problematic_object.expect(
        :as_json,
        -> { raise "Error while processing as_json" }
      ).expect(:is_a?, false, [Class])

      # We expect the formatter to handle this gracefully without infinite recursion
      formatter = LogStruct::Formatter.new

      # Mock the error handling to avoid actual error reporting during tests
      LogStruct.stub(:handle_exception, nil) do
        # Should not raise SystemStackError
        log_line = T.let(nil, T.nilable(String))
        assert_nothing_raised do
          log_line = formatter.call("INFO", Time.now, nil, problematic_object)
        end

        # Since we mocked handle_exception, just verify that we got a log line back
        assert_not_nil log_line
        assert_kind_of String, log_line

        # It should still be valid JSON
        assert_nothing_raised do
          JSON.parse(T.must(log_line))
        end
      end
    end

    def test_writes_binary_and_invalid_strings_and_keys_as_utf8
      user_agent = (+"Agent \xFF").force_encoding(Encoding::BINARY)
      key = (+"k\xFE").force_encoding(Encoding::BINARY)

      log_line = @formatter.call(@severity, @time, @progname, {:msg => "Request", :user_agent => user_agent, key => 1, :note => "caf\xE9"})
      result = JSON.parse(log_line)

      assert_equal "Agent \uFFFD", result["user_agent"]
      assert_equal 1, result["k\uFFFD"]
      assert_equal "caf\uFFFD", result["note"]
    end

    def test_writes_nan_and_infinity_as_strings
      result = JSON.parse(@formatter.call(@severity, @time, @progname, {msg: "Ratios", nan: Float::NAN, inf: -Float::INFINITY}))

      assert_equal "NaN", result["nan"]
      assert_equal "-Infinity", result["inf"]
    end

    def test_cuts_long_strings_after_scrubbing_them
      LogStruct.config.limits.max_string_bytes = 100
      # An email address across the cut is scrubbed whole
      long = "#{"a" * 90} ada@example.com #{"b" * 200}"

      value = JSON.parse(@formatter.call(@severity, @time, @progname, {msg: "Long", body: long}))["body"]

      assert_operator value.bytesize, :<, 150
      assert_match(/\.\.\. \(cut from #{long.bytesize} bytes\)\z/, value)
      assert_not_includes value, "ada@"
      assert_includes value, "[EMAIL:"
    end

    def test_scrubs_a_long_url_password_that_the_cut_separates_from_its_host
      LogStruct.config.limits.max_string_bytes = 100
      # The password runs past the scrubbers' margin, so its closing @ is beyond what they see
      secret = "s3cr3t" * 60
      plain = "#{"a" * 10} https://user:#{secret}@db.example.com/app"
      # cspell:ignore Fuser
      encoded = "#{"a" * 10} https%3A%2F%2Fuser%3A#{secret}%40db.example.com"

      [plain, encoded].each do |long|
        value = JSON.parse(@formatter.call(@severity, @time, @progname, {msg: "Long", body: long}))["body"]

        assert_not_includes value, "s3cr3t", long[0, 30]
        assert_includes value, "[PASSWORD]", long[0, 30]
      end
    end

    def test_scrubs_a_long_url_password_with_an_at_sign_that_the_cut_separates_from_its_host
      LogStruct.config.limits.max_string_bytes = 100
      # The scrubbers see the password's own @ and take it for the one before the host
      secret = "s3cr3t" * 60
      plain = "#{"a" * 10} https://user:p@#{secret}@db.example.com/app"
      encoded = "#{"a" * 10} https%3A%2F%2Fuser%3Ap%40#{secret}%40db.example.com"

      [plain, encoded].each do |long|
        value = JSON.parse(@formatter.call(@severity, @time, @progname, {msg: "Long", body: long}))["body"]

        assert_not_includes value, "s3cr3t", long[0, 30]
        assert_includes value, "[PASSWORD]", long[0, 30]
      end
    end

    def test_scrubs_basic_credentials_that_the_cut_runs_through
      LogStruct.config.limits.max_string_bytes = 100
      credentials = Base64.strict_encode64("ada:#{"s3cr3t" * 60}")
      # The scrubbers see a part of the credentials that is no Base64 value
      long = "#{"a" * 31} Authorization: Basic #{credentials}"

      value = JSON.parse(@formatter.call(@severity, @time, @progname, {msg: "Long", body: long}))["body"]

      assert_not_includes value, credentials[0, 8]
      assert_includes value, "Basic [FILTERED]"
    end

    def test_leaves_a_cut_url_without_a_password
      LogStruct.config.limits.max_string_bytes = 100
      long = "#{"a" * 70} https://example.com/#{"b" * 200}"

      value = JSON.parse(@formatter.call(@severity, @time, @progname, {msg: "Long", body: long}))["body"]

      assert_includes value, "https://example.com/bbb"
      assert_not_includes value, "[PASSWORD]"
    end

    def test_writes_the_first_keys_of_a_large_hash
      LogStruct.config.limits.max_hash_keys = 3

      result = JSON.parse(@formatter.call(@severity, @time, @progname, {msg: "Big", data: (1..10).to_h { |i| ["k#{i}", i] }}))

      assert_equal({"k1" => 1, "k2" => 2, "k3" => 3, "_more_keys" => 7}, result["data"])
    end

    def test_writes_the_first_lines_of_a_backtrace_like_array
      result = JSON.parse(@formatter.call(@severity, @time, @progname, {msg: "Trace", lines: ["a:0"] * 150}))

      assert_equal 21, result["lines"].size
      assert_equal "... and 130 more lines", result["lines"].last
    end

    def test_an_error_lines_backtrace_has_max_backtrace_lines
      error = ArgumentError.new("bad input")
      error.set_backtrace((1..30).map { |line| "app/models/user.rb:#{line}:in 'save'" })

      result = JSON.parse(@formatter.call(::Logger::ERROR, @time, @progname, error))

      assert_equal 21, result["backtrace"].size
      assert_equal "... and 10 more lines", result["backtrace"].last
    end

    def test_logs_exceptions_with_their_class_message_and_backtrace
      error = ArgumentError.new("bad input")
      error.set_backtrace(["app/models/user.rb:3:in 'save'"])

      result = JSON.parse(@formatter.call(::Logger::ERROR, @time, @progname, error))

      assert_equal %w[app error error ArgumentError bad\ input], result.values_at("src", "evt", "lvl", "error_class", "msg")
      assert_equal ["app/models/user.rb:3:in 'save'"], result["backtrace"]
    end

    def test_writes_a_placeholder_line_when_a_line_cant_be_written
      formatter = Class.new(Formatter) do
        def generate_json(data)
          raise JSON::GeneratorError, "can't write" if data[:msg] == "unwritable"

          super
        end
      end.new
      reported = []

      log_line = LogStruct.stub(:is_production?, true) do
        LogStruct.stub(:handle_exception, ->(error, **) { reported << error.message }) do
          formatter.call(@severity, @time, @progname, {msg: "unwritable", job: "SyncJob"})
        end
      end
      result = JSON.parse(log_line)

      assert_equal ["can't write"], reported
      assert_equal "LogStruct couldn't write this line as JSON", result["msg"]
      assert_equal %w[app log info JSON::GeneratorError], result.values_at("src", "evt", "lvl", "error_class")
    end

    def test_summarizes_objects_whose_as_json_overflows_the_stack
      looping = Class.new do
        def as_json(*)
          raise SystemStackError, "stack level too deep"
        end
      end.new

      log_line = LogStruct.stub(:is_production?, true) do
        @formatter.call(@severity, @time, @progname, {msg: "Loop", value: looping})
      end

      assert_equal "Loop", JSON.parse(log_line)["msg"]
    end

    private

    def create_user_class
      Class.new do
        include GlobalID::Identification
        attr_accessor :id

        def initialize(id)
          @id = id
        end

        def to_global_id
          GlobalID.new("gid://logstruct/User/#{@id}")
        end

        def self.name
          "User"
        end
      end
    end
  end
end
