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
        # Output is now valid JSON, so look for JSON format
        assert_includes output, '"src":', "Should include the source field in JSON format"
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

      # This test reproduces the production bug where logs show Ruby hash inspect:
      # {message: "...", tags: ["tag"]}
      # instead of valid JSON:
      # {"message":"...","tags":["tag"]}
      def test_output_is_not_ruby_hash_inspect_format
        LogStruct.config.enabled = true

        @tagged_logger.tagged("my_tag") do
          @tagged_logger.info("Test message")
        end

        output = @output.string

        # MUST NOT be Ruby hash inspect format with symbol keys
        refute_match(/\{message:/,
          output,
          "Output must NOT be Ruby hash inspect format like {message: ...}")
        refute_match(/\{:message\s*=>/,
          output,
          "Output must NOT be Ruby hash rocket format like {:message => ...}")
        refute_match(/tags:\s*\[/,
          output,
          "Output must NOT have symbol :tags key")
      end

      def test_tagged_output_is_not_ruby_hash_inspect_format
        LogStruct.config.enabled = true

        # Simulate what happens with AMS or other tagged logging
        @tagged_logger.tagged("active_model_serializers") do
          @tagged_logger.info("Rendered SubmissionSerializer with Attributes (14.12ms)")
        end

        output = @output.string

        # This is the exact broken format from production:
        # [active_model_serializers] {message: "Rendered ...", tags: ["active_model_serializers"]}
        refute_match(/\[active_model_serializers\]\s*\{message:/,
          output,
          "Must NOT output [tag] {message: ...} format")

        # Tags should be incorporated properly, not in broken format
        refute_match(/\{message:.*tags:/,
          output,
          "Must NOT output {message: ..., tags: ...} Ruby inspect format")
      end
    end
  end
end
