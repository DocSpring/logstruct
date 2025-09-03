# typed: true
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

      assert_instance_of GlobalID, result
      assert_equal "gid://logstruct/User/123", result.to_s
    end

    def test_process_values_formats_hashes_recursively
      user_class = create_user_class
      user = user_class.new(123)
      arg = {user: user, data: {value: "test"}}

      result = @formatter.process_values(arg)

      assert_instance_of GlobalID, result[:user]
      assert_equal "gid://logstruct/User/123", result[:user].to_s
      assert_equal "test", result[:data][:value]
    end

    def test_process_values_formats_arrays_recursively
      user_class = create_user_class
      user = user_class.new(123)
      arg = [user, {email: "test@example.com"}]

      result = @formatter.process_values(arg)

      assert_instance_of GlobalID, result[0]
      assert_equal "gid://logstruct/User/123", result[0].to_s
      assert_not_includes result[1][:email], "test@example.com"
    end

    def test_process_values_truncates_large_arrays
      arg = (1..20).to_a
      result = @formatter.process_values(arg)

      assert_equal 11, result.length
      assert_equal "... and 10 more items", result.last
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
