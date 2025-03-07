# typed: true
# frozen_string_literal: true

require "test_helper"
require "shrine"
require "ostruct"
require "tempfile"

module LogStruct
  module Integrations
    class ShrineTest < ActiveSupport::TestCase
      # Track plugin calls to Shrine
      class PluginTracker
        def initialize
          @calls = []
        end

        attr_reader :calls

        def track(name, *args, **kwargs)
          @calls << {name: name, args: args, kwargs: kwargs}
        end

        def find_plugin(name)
          @calls.find { |call| call[:name] == name }
        end

        def has_plugin?(name)
          !find_plugin(name).nil?
        end
      end

      def setup
        # Skip tests if Shrine is not available
        skip "Shrine not available" unless defined?(::Shrine)

        # Save original configuration
        @original_config = LogStruct.config.dup

        # Save the original plugin method to restore it later
        @original_plugin_method = ::Shrine.method(:plugin)

        # Set up our plugin tracker
        @plugin_tracker = PluginTracker.new

        # Override Shrine's plugin method to track calls to it
        ::Shrine.define_singleton_method(:plugin) do |name, *args, **kwargs, &block|
          T.unsafe(self).instance_variable_get(:@plugin_tracker).track(name, *args, **kwargs)
          T.unsafe(self).instance_variable_get(:@original_plugin_method).call(name, *args, **kwargs, &block)
        end

        ::Shrine.instance_variable_set(:@plugin_tracker, @plugin_tracker)
        ::Shrine.instance_variable_set(:@original_plugin_method, @original_plugin_method)

        # Default configuration for tests
        LogStruct.configure do |config|
          config.enabled = true
          config.integrations.enable_shrine = true
        end
      end

      def teardown
        # Restore original configuration
        LogStruct.configuration = @original_config

        # Restore original plugin method if we changed it
        if @original_plugin_method
          ::Shrine.define_singleton_method(:plugin, @original_plugin_method)
          ::Shrine.remove_instance_variable(:@plugin_tracker) if ::Shrine.instance_variable_defined?(:@plugin_tracker)
          ::Shrine.remove_instance_variable(:@original_plugin_method) if ::Shrine.instance_variable_defined?(:@original_plugin_method)
        end
      end

      def test_setup_configures_shrine_with_instrumentation
        # Setup the integration
        LogStruct::Integrations::Shrine.setup(LogStruct.config)

        # Verify Shrine was configured with the instrumentation plugin
        assert @plugin_tracker.has_plugin?(:instrumentation), "Shrine instrumentation plugin not loaded"

        # Verify the log events are set correctly
        plugin_call = @plugin_tracker.find_plugin(:instrumentation)

        assert_equal %i[upload exists download delete], plugin_call[:kwargs][:log_events]

        # Verify a log_subscriber was provided
        assert_kind_of Proc, plugin_call[:kwargs][:log_subscriber]
      end

      def test_setup_does_nothing_when_shrine_disabled
        # Disable Shrine integration
        LogStruct.configure do |config|
          config.integrations.enable_shrine = false
        end

        # Clear existing calls
        @plugin_tracker.calls.clear

        # Setup the integration
        LogStruct::Integrations::Shrine.setup(LogStruct.config)

        # Verify no plugins were loaded
        assert_empty @plugin_tracker.calls, "No plugins should be loaded when Shrine integration is disabled"
      end

      def test_setup_does_nothing_when_logstruct_disabled
        # Disable LogStruct
        LogStruct.configure do |config|
          config.enabled = false
        end

        # Clear existing calls
        @plugin_tracker.calls.clear

        # Setup the integration
        LogStruct::Integrations::Shrine.setup(LogStruct.config)

        # Verify no plugins were loaded
        assert_empty @plugin_tracker.calls, "No plugins should be loaded when LogStruct is disabled"
      end

      def test_log_subscriber_creates_structured_logs
        # Setup the integration
        LogStruct::Integrations::Shrine.setup(LogStruct.config)

        # Get the log subscriber
        plugin_call = @plugin_tracker.find_plugin(:instrumentation)
        log_subscriber = plugin_call[:kwargs][:log_subscriber]

        # Create a mock ActiveSupport::Notifications::Event
        event = OpenStruct.new(
          name: :upload,
          duration: 123.45,
          payload: {
            storage: "disk",
            location: "uploads/image.jpg",
            uploader: "ImageUploader",
            upload_options: {acl: "public-read"},
            io: StringIO.new("mock file data"),
            metadata: {size: 12345, mime_type: "image/jpeg"},
            extra_data: "some value"
          }
        )

        # Use a StringIO to capture log output
        log_output = StringIO.new
        test_logger = ::Logger.new(log_output)
        
        # Replace the Shrine logger with our test logger
        ::Shrine.stub(:logger, test_logger) do
          # Call the log subscriber with our mock event
          log_subscriber.call(event)
          
          # Verify log output contains expected data
          log_output.rewind
          log_str = log_output.string
          
          # The formatter in tests may not be structured, but we can check for key elements
          assert_includes log_str, "storage"
          assert_includes log_str, "disk"
          assert_includes log_str, "location"
          assert_includes log_str, "uploads/image.jpg"
        end
      end

      def test_log_subscriber_handles_different_event_types
        # Setup the integration
        LogStruct::Integrations::Shrine.setup(LogStruct.config)

        # Get the log subscriber
        plugin_call = @plugin_tracker.find_plugin(:instrumentation)
        log_subscriber = plugin_call[:kwargs][:log_subscriber]

        # Test different event types
        event_types = {
          upload: LogEvent::Upload,
          download: LogEvent::Download,
          delete: LogEvent::Delete,
          metadata: LogEvent::Metadata,
          exists: LogEvent::Exist,
          unknown_event: LogEvent::Unknown
        }

        event_types.each do |event_name, expected_log_event|
          # Create a mock event for this event type
          event = OpenStruct.new(
            name: event_name,
            duration: 123.45,
            payload: {
              storage: "disk",
              location: "uploads/image.jpg"
            }
          )

          # Use a mock logger to capture data
          mock_logger = Minitest::Mock.new

          # The mock expects an info call with a log struct that has the correct event type
          mock_logger.expect(:info, nil) do |log_struct|
            assert_equal expected_log_event, log_struct.event
            true
          end

          # Replace the logger with our mock
          ::Shrine.stub(:logger, mock_logger) do
            # Call the log subscriber
            log_subscriber.call(event)
          end

          # Verify all expected methods were called
          mock_logger.verify
        end
      end
    end
  end
end
