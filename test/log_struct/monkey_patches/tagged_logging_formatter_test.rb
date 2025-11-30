# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  module MonkeyPatches
    class TaggedLoggingFormatterTest < ActiveSupport::TestCase
      setup do
        @original_config = LogStruct.config.dup
        @output = StringIO.new
        @logger = Logger.new(@output)
        @tagged_logger = ActiveSupport::TaggedLogging.new(@logger)
      end

      teardown do
        LogStruct.configuration = @original_config
      end

      def test_preserves_original_rails_behavior_when_disabled
        LogStruct.config.enabled = false

        @tagged_logger.info("Test message")

        output = @output.string

        assert_includes output, "Test message"
        refute_includes output, "message:"
        refute_includes output, "{"
      end

      def test_wraps_messages_in_hash_when_enabled
        LogStruct.config.enabled = true

        @tagged_logger.info("Test message")

        output = @output.string

        assert_includes output, "message"
      end

      def test_passes_through_hash_data_when_enabled
        LogStruct.config.enabled = true

        @tagged_logger.info({event: "test", data: "value"})

        output = @output.string

        assert_includes output, "event"
        assert_includes output, "data"
      end

      def test_passes_through_hash_data_when_disabled
        LogStruct.config.enabled = false

        @tagged_logger.info({event: "test", data: "value"})

        output = @output.string

        assert_includes output, "event"
        assert_includes output, "data"
      end
    end
  end
end
