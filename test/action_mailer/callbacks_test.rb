# frozen_string_literal: true

require 'test_helper'

class ActionMailerCallbacksTest < Minitest::Test
  def setup
    # Mock Rails and ActionMailer
    Object.const_set(:Rails, Module.new) unless defined?(::Rails)
    ::Rails.singleton_class.class_eval do
      def gem_version
        @gem_version ||= Gem::Version.new('7.0.0')
      end
    end

    Object.const_set(:ActionMailer, Module.new) unless defined?(::ActionMailer)
    ::ActionMailer.const_set(:Base, Class.new) unless defined?(::ActionMailer::Base)
    ::ActionMailer.const_set(:MessageDelivery, Class.new) unless defined?(::ActionMailer::MessageDelivery)

    # Mock ActiveSupport
    Object.const_set(:ActiveSupport, Module.new) unless defined?(::ActiveSupport)
    ::ActiveSupport.singleton_class.class_eval do
      def on_load(name, &block)
        @on_load_blocks ||= {}
        @on_load_blocks[name] = block
      end

      def execute_on_load(name)
        @on_load_blocks ||= {}
        @on_load_blocks[name]&.call
      end
    end

    # Mock ActionMailer::Base
    ::ActionMailer::Base.class_eval do
      def self.include(mod)
        @included_modules ||= []
        @included_modules << mod
      end

      def self.included_modules
        @included_modules ||= []
      end

      def handle_exceptions
        yield
      end

      def run_callbacks(name)
        yield
      end
    end

    # Mock ActionMailer::MessageDelivery
    ::ActionMailer::MessageDelivery.class_eval do
      attr_accessor :processed_mailer, :message

      def initialize
        @processed_mailer = ::ActionMailer::Base.new
        @message = Object.new
        @message.define_singleton_method(:deliver) { true }
        @message.define_singleton_method(:deliver!) { true }
      end

      def deliver_now
        message.deliver
      end

      def deliver_now!
        message.deliver!
      end
    end

    # Reset configuration
    RailsStructuredLogging.configure do |config|
      config.enabled = true
      config.actionmailer_integration_enabled = true
    end
  end

  def teardown
    # Clean up
    ::ActionMailer::Base.instance_variable_set(:@included_modules, [])
    ::ActionMailer::MessageDelivery.instance_variable_set(:@original_deliver_now, nil)
    ::ActionMailer::MessageDelivery.instance_variable_set(:@original_deliver_now!, nil)
  end

  def test_callbacks_setup_for_rails_7_0
    # Call setup
    RailsStructuredLogging::ActionMailer.setup

    # Execute the on_load block
    ::ActiveSupport.execute_on_load(:action_mailer)

    # Verify that the callbacks module was included
    assert_includes ::ActionMailer::Base.included_modules, RailsStructuredLogging::ActionMailer::Callbacks

    # Verify that MessageDelivery was patched
    message_delivery = ::ActionMailer::MessageDelivery.new

    # Test that deliver_now calls run_callbacks
    called = false
    message_delivery.processed_mailer.define_singleton_method(:run_callbacks) do |name|
      assert_equal :deliver, name
      called = true
      yield
    end

    message_delivery.deliver_now
    assert called, "run_callbacks should have been called"
  end

  def test_callbacks_not_setup_for_rails_7_1
    # Set Rails version to 7.1.0
    ::Rails.singleton_class.class_eval do
      def gem_version
        @gem_version = Gem::Version.new('7.1.0')
      end
    end

    # Call setup
    RailsStructuredLogging::ActionMailer.setup

    # Execute the on_load block
    ::ActiveSupport.execute_on_load(:action_mailer)

    # Verify that the callbacks module was not included
    refute_includes ::ActionMailer::Base.included_modules, RailsStructuredLogging::ActionMailer::Callbacks
  end

  def test_callbacks_not_setup_when_disabled
    # Disable ActionMailer integration
    RailsStructuredLogging.configure do |config|
      config.actionmailer_integration_enabled = false
    end

    # Call setup
    RailsStructuredLogging::ActionMailer.setup

    # Execute the on_load block
    ::ActiveSupport.execute_on_load(:action_mailer)

    # Verify that the callbacks module was not included
    refute_includes ::ActionMailer::Base.included_modules, RailsStructuredLogging::ActionMailer::Callbacks
  end
end
