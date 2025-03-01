# frozen_string_literal: true

require "spec_helper"
require "rails"
require "action_mailer"
require "active_support"

RSpec.describe RailsStructuredLogging::ActionMailer::Callbacks, if: Rails.gem_version < Gem::Version.new("7.1.0") do
  # Create a test mailer class that inherits from ActionMailer::Base
  let(:test_mailer_class) do
    Class.new(ActionMailer::Base) do
      include RailsStructuredLogging::ActionMailer::Callbacks

      def self.name
        "TestMailer"
      end

      attr_reader :before_called, :after_called, :around_before_called, :around_after_called

      def initialize
        super
        @before_called = false
        @after_called = false
        @around_before_called = false
        @around_after_called = false
      end

      before_deliver :before_callback
      after_deliver :after_callback
      around_deliver :around_callback

      def before_callback
        @before_called = true
      end

      def after_callback
        @after_called = true
      end

      def around_callback
        @around_before_called = true
        yield
        @around_after_called = true
      end

      def test_method
        run_callbacks(:deliver) do
          # Simulate delivery
        end
      end
    end
  end

  it "defines callback methods" do
    expect(test_mailer_class).to respond_to(:before_deliver)
    expect(test_mailer_class).to respond_to(:after_deliver)
    expect(test_mailer_class).to respond_to(:around_deliver)
  end

  it "executes callbacks in the correct order" do
    mailer = test_mailer_class.new
    mailer.test_method

    expect(mailer.before_called).to be true
    expect(mailer.after_called).to be true
    expect(mailer.around_before_called).to be true
    expect(mailer.around_after_called).to be true
  end

  describe ".patch_message_delivery" do
    before do
      # Create a mock MessageDelivery class for testing
      class ActionMailer::MessageDelivery
        def initialize; end
        def deliver; end
        def deliver!; end
        def processed_mailer; end
      end

      # Allow class_eval to be called
      allow_any_instance_of(ActionMailer::MessageDelivery).to receive(:processed_mailer).and_return(
        double("Mailer", handle_exceptions: true, run_callbacks: true)
      )
    end

    after do
      # Clean up
      ActionMailer.send(:remove_const, :MessageDelivery) if defined?(ActionMailer::MessageDelivery)
    end

    it "patches MessageDelivery with deliver_now and deliver_now! methods" do
      # Apply the patch
      described_class.patch_message_delivery

      # Create a new instance
      message_delivery = ActionMailer::MessageDelivery.new

      # Verify the methods were patched
      expect(message_delivery).to respond_to(:deliver_now)
      expect(message_delivery).to respond_to(:deliver_now!)
    end
  end
end
