# typed: false
# frozen_string_literal: true

require "test_helper"

module LogStruct
  class FormatterTest < ActiveSupport::TestCase
    def setup
      @formatter = Formatter.new
      @severity = "INFO"
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
      assert_equal "info", result["level"]
      assert_equal @progname, result["progname"]
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
        source: LogStruct::Source::App,
        level: LogStruct::LogLevel::Info
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
      user_class = create_user_class
      broken_user = user_class.new(456)

      # Mock the to_global_id method to raise an error
      def broken_user.to_global_id
        raise StandardError, "Can't serialize"
      end

      message = {
        source: "active_job",
        arguments: [broken_user]
      }

      result = JSON.parse(@formatter.call(@severity, @time, @progname, message))

      assert_equal "[GLOBALID_ERROR]", result["arguments"][0]
    end

    def test_tagged_logging_support
      # Test current_tags
      assert_empty @formatter.current_tags
      Thread.current[:activesupport_tagged_logging_tags] = %w[tag1 tag2]

      assert_equal %w[tag1 tag2], @formatter.current_tags
    end

    def test_tagged_method
      result = nil
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

    private

    def create_user_class
      Class.new do
        include GlobalID::Identification
        attr_accessor :id

        def initialize(id)
          @id = id
        end

        def to_global_id
          GlobalID.new("gid://logstruct/User/#{id}")
        end

        def self.name
          "User"
        end
      end
    end
  end
end
