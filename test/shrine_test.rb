# frozen_string_literal: true

require 'test_helper'

class ShrineTest < Minitest::Test
  def setup
    # Mock Shrine class and logger
    Object.const_set(:Shrine, Class.new) unless defined?(::Shrine)
    ::Shrine.singleton_class.class_eval do
      attr_accessor :logger

      def plugin(name, **options)
        @plugins ||= {}
        @plugins[name] = options
      end

      def plugins
        @plugins ||= {}
      end
    end

    ::Shrine.logger = Logger.new(StringIO.new)

    # Reset configuration
    RailsStructuredLogging.configure do |config|
      config.enabled = true
      config.shrine_integration_enabled = true
    end
  end

  def teardown
    # Clean up
    ::Shrine.singleton_class.class_eval do
      @plugins = {}
    end
  end

  def test_shrine_integration_setup
    # Call setup
    RailsStructuredLogging::Shrine.setup

    # Verify that the instrumentation plugin was configured
    assert ::Shrine.plugins.key?(:instrumentation)
    assert_equal [:upload, :exists, :download, :delete], ::Shrine.plugins[:instrumentation][:log_events]
    assert ::Shrine.plugins[:instrumentation][:log_subscriber].is_a?(Proc)
  end

  def test_shrine_integration_disabled
    # Disable integration
    RailsStructuredLogging.configure do |config|
      config.shrine_integration_enabled = false
    end

    # Call setup
    RailsStructuredLogging::Shrine.setup

    # Verify that the instrumentation plugin was not configured
    assert_empty ::Shrine.plugins
  end

  def test_shrine_log_subscriber
    # Call setup to get the log subscriber
    RailsStructuredLogging::Shrine.setup
    log_subscriber = ::Shrine.plugins[:instrumentation][:log_subscriber]

    # Create a mock event
    event = Struct.new(:name, :duration, :payload).new(
      'upload',
      123.45,
      {
        io: StringIO.new('test'),
        metadata: { 'mime_type' => 'text/plain' },
        storage: :store,
        location: 'test.txt',
        options: {
          record: Struct.new(:id, :class).new(123, Struct.new(:name).new('TestModel'))
        }
      }
    )

    # Capture logger output
    output = StringIO.new
    ::Shrine.logger = Logger.new(output)

    # Call the log subscriber
    log_subscriber.call(event)

    # Verify the output
    output.rewind
    log_entry = output.read

    # Basic assertions
    assert_includes log_entry, '"src":"shrine"'
    assert_includes log_entry, '"evt":"upload"'
    assert_includes log_entry, '"duration":123.45'
    assert_includes log_entry, '"storage":"store"'
    assert_includes log_entry, '"location":"test.txt"'

    # Verify record handling
    assert_includes log_entry, '"record_id":123'
    assert_includes log_entry, '"record_class":"TestModel"'
    refute_includes log_entry, '"record":'
  end
end
