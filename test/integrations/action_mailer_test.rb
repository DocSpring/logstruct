# typed: false # rubocop:disable Sorbet/TrueSigil
# frozen_string_literal: true

require_relative "../test_helper"
require "action_mailer"
require "action_view"

class ActionMailerIntegrationTest < ActiveSupport::TestCase
  class CustomError < StandardError; end

  class AnotherError < StandardError; end

  # Test mailer with custom rescue_from handlers
  class TestMailer < ActionMailer::Base
    default from: "test@example.com"

    # User-defined custom error handler (should take precedence)
    rescue_from CustomError do |exception|
      Rails.logger.info "Custom handler caught: #{exception.message}"
      # Don't reraise - handle the error
    end

    rescue_from AnotherError do |exception|
      Rails.logger.info "AnotherError handler caught: #{exception.message}"
      # Reraise for demonstration
      raise exception
    end

    def test_email
      mail(to: "recipient@example.com", subject: "Test") do |format|
        format.text { render plain: "Test email" }
      end
    end

    # These methods should trigger rescue_from when called during deliver process
    def custom_error_during_delivery
      raise CustomError, "This is a custom error"
    end

    def another_error_during_delivery
      raise AnotherError, "This is another error"
    end

    def standard_error_during_delivery
      raise StandardError, "This is a standard error"
    end
  end

  # Mailer that inherits from a base class with handlers
  class ApplicationMailer < ActionMailer::Base
    default from: "app@example.com"

    # Application-level handler
    rescue_from StandardError do |exception|
      Rails.logger.error "App handler caught: #{exception.message}"
      raise exception # Reraise for retry
    end
  end

  class InheritedMailer < ApplicationMailer
    def test_email
      mail(to: "recipient@example.com", subject: "Test") do |format|
        format.text { render plain: "Test email" }
      end
    end

    def error_during_delivery
      raise StandardError, "Error in inherited mailer"
    end
  end

  setup do
    @original_logger = Rails.logger
    @log_output = StringIO.new
    Rails.logger = Logger.new(@log_output)

    # Store original configuration
    @original_config = LogStruct.configuration.dup

    # Enable ActionMailer integration
    LogStruct.configure do |config|
      config.enabled = true
      config.integrations.enable_actionmailer = true
    end

    # Set up ActionMailer for testing
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
  end

  teardown do
    Rails.logger = @original_logger
    LogStruct.configuration = @original_config
    ActionMailer::Base.deliveries.clear
  end

  test "user rescue_from that swallows error without LogStruct still logs Delivery and Delivered" do
    # Setup LogStruct ActionMailer integration
    LogStruct::Integrations::ActionMailer.setup(LogStruct.configuration)

    # Include all our modules (simulates what happens on_load)
    TestMailer.include LogStruct::Integrations::ActionMailer::ErrorHandling

    # The custom error should be handled by the user's handler
    assert_nothing_raised do
      TestMailer.custom_error_during_delivery.deliver_now
    end

    # Check that the custom handler ran (it logged a message)
    log_content = @log_output.string

    assert_match(/Custom handler caught: This is a custom error/, log_content)

    # Since user swallowed error without calling log_and_ignore_error, callbacks still run
    assert_match(/mailer_class/, log_content)
    assert_match(/Delivery/, log_content)
    assert_match(/Delivered/, log_content)
  end

  test "user rescue_from that calls log_and_ignore_error suppresses Delivered event" do
    # Create a mailer that uses log_and_ignore_error
    test_mailer = Class.new(ActionMailer::Base) do
      default from: "test@example.com"

      rescue_from StandardError do |ex|
        log_and_ignore_error(ex)
      end

      def error_during_delivery
        raise StandardError, "Test error"
      end
    end

    # Setup LogStruct
    LogStruct::Integrations::ActionMailer.setup(LogStruct.configuration)
    test_mailer.include LogStruct::Integrations::ActionMailer::ErrorHandling

    assert_nothing_raised do
      test_mailer.error_during_delivery.deliver_now
    end

    log_content = @log_output.string

    # Should have error log from log_and_ignore_error
    assert_match(/Test error/, log_content)

    # Should have Delivery event
    assert_match(/Delivery/, log_content)

    # Should NOT have Delivered event (suppressed by logstruct_mail_failed flag)
    refute_match(/Delivered/, log_content)
  end

  test "user handlers that reraise still trigger LogStruct logging" do
    # Setup LogStruct ActionMailer integration
    LogStruct::Integrations::ActionMailer.setup(LogStruct.configuration)
    TestMailer.include LogStruct::Integrations::ActionMailer::ErrorHandling

    # AnotherError is caught by user handler but reraises
    assert_raises(AnotherError) do
      TestMailer.another_error_during_delivery.deliver_now
    end

    log_content = @log_output.string

    # User handler should have logged
    assert_match(/AnotherError handler caught: This is another error/, log_content)

    # LogStruct should have also logged the error (since it was re-raised and not handled)
    assert_match(/This is another error/, log_content)
  end

  test "LogStruct handler works with inherited mailers" do
    # Setup LogStruct ActionMailer integration
    LogStruct::Integrations::ActionMailer.setup(LogStruct.configuration)
    InheritedMailer.include LogStruct::Integrations::ActionMailer::ErrorHandling

    # Error should be caught by ApplicationMailer's handler first
    assert_raises(StandardError) do
      InheritedMailer.error_during_delivery.deliver_now
    end

    log_content = @log_output.string
    # Both user handler and LogStruct should have logged
    assert_match(/App handler caught: Error in inherited mailer/, log_content)
    assert_match(/Error in inherited mailer/, log_content)
  end

  test "unhandled errors are caught by LogStruct default handler" do
    # Create a mailer without custom handlers
    simple_mailer = Class.new(ActionMailer::Base) do
      default from: "test@example.com"

      def error_during_delivery
        raise StandardError, "Unhandled error"
      end
    end

    # Setup LogStruct
    LogStruct::Integrations::ActionMailer.setup(LogStruct.configuration)
    simple_mailer.include LogStruct::Integrations::ActionMailer::ErrorHandling

    # Should be caught by our default handler
    assert_raises(StandardError) do
      simple_mailer.error_during_delivery.deliver_now
    end

    log_content = @log_output.string
    # Should have our error logging
    assert_match(/Unhandled error/, log_content)
    # Should have structured logging from LogStruct
    assert_match(/will retry/, log_content)
  end

  test "LogStruct error handling can be disabled" do
    # Disable ActionMailer integration
    LogStruct.configure do |config|
      config.integrations.enable_actionmailer = false
    end

    result = LogStruct::Integrations::ActionMailer.setup(LogStruct.configuration)

    assert_nil result, "Setup should return nil when disabled"

    # Without LogStruct modules, errors should not be handled by LogStruct
    # but user rescue_from handlers will still work
    assert_nothing_raised do
      TestMailer.custom_error_during_delivery.deliver_now
    end

    # Only the rails default logger should have any output (not LogStruct structured)
    log_content = @log_output.string

    refute_match(/will retry/, log_content)
  end

  test "rescue_from handlers are checked in correct inheritance order" do
    # Create a complex inheritance chain
    base_mailer = Class.new(ActionMailer::Base) do
      default from: "base@example.com"

      rescue_from StandardError do |e|
        Rails.logger.info "Base handler: #{e.message}"
        raise e
      end
    end

    child_mailer = Class.new(base_mailer) do
      rescue_from ArgumentError do |e|
        Rails.logger.info "Child ArgumentError handler: #{e.message}"
      end

      rescue_from RuntimeError do |e|
        Rails.logger.info "Child RuntimeError handler: #{e.message}"
        raise e
      end

      def test_argument_error
        raise ArgumentError, "Invalid argument"
      end

      def test_runtime_error
        raise "Runtime problem"
      end
    end

    # Setup LogStruct
    LogStruct::Integrations::ActionMailer.setup(LogStruct.configuration)
    child_mailer.include LogStruct::Integrations::ActionMailer::ErrorHandling

    # ArgumentError should be caught by child's specific handler
    assert_nothing_raised do
      child_mailer.test_argument_error.deliver_now
    end
    assert_match(/Child ArgumentError handler: Invalid argument/, @log_output.string)

    @log_output.truncate(0)

    # RuntimeError should be caught by child handler, then reraise (not to base handler)
    # Note: Rails rescue_from doesn't bubble to parent handlers after reraise
    assert_raises(RuntimeError) do
      child_mailer.test_runtime_error.deliver_now
    end
    log_content = @log_output.string

    assert_match(/Child RuntimeError handler: Runtime problem/, log_content)
    # Base handler should NOT be called - Rails doesn't bubble to parent rescue_from after reraise
    refute_match(/Base handler: Runtime problem/, log_content)
  end
end
