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

      def test_serializes_logstruct_structs_when_enabled
        LogStruct.config.enabled = true

        log_struct = LogStruct::Log::Plain.new(
          message: "Test structured message"
        )

        @tagged_logger.info(log_struct)

        output = @output.string

        # Should serialize the struct to hash, NOT call .to_s on it
        refute_includes output,
          "#<LogStruct::Log::Plain:",
          "LogStruct structs should be serialized, not converted to string"
        assert_includes output, "src:", "Should include the source field"
        assert_includes output, "Test structured message", "Should include the message"
      end

      def test_serializes_shrine_upload_struct_when_enabled
        LogStruct.config.enabled = true

        log_struct = LogStruct::Log::Shrine::Upload.new(
          storage: :store,
          location: "test/path.pdf",
          uploader: "DocumentUploader",
          duration_ms: 150.5
        )

        @tagged_logger.info(log_struct)

        output = @output.string

        # Should serialize the struct to hash, NOT call .to_s on it
        refute_includes output,
          "#<LogStruct::Log::Shrine::Upload:",
          "LogStruct structs should be serialized, not converted to string"
        assert_includes output, "store", "Should include the storage"
        assert_includes output, "test/path.pdf", "Should include the location"
      end
    end
  end
end
