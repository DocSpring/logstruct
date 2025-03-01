# frozen_string_literal: true

require "spec_helper"
require "rails"
require "action_mailer"
require "active_support"

RSpec.describe RailsStructuredLogging::ActionMailer::Callbacks, if: Rails.gem_version < Gem::Version.new("7.1.0") do
  describe "delivery callbacks" do
    # Define a test mailer class for testing callbacks using Class.new
    let(:test_mailer_class) do
      Class.new do
        include RailsStructuredLogging::ActionMailer::Callbacks

        attr_reader :before_called, :after_called, :around_before_called, :around_after_called

        def self.name
          "TestMailer"
        end

        def initialize
          super
          @before_called = false
          @after_called = false
          @around_before_called = false
          @around_after_called = false
        end

        # Define callbacks
        before_deliver :before_callback
        after_deliver :after_callback
        around_deliver :around_callback

        # Callback methods
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

        # Test method to trigger callbacks
        def test_method
          run_callbacks(:deliver) do
            # This would be the actual delivery in a real mailer
            true
          end
        end
      end
    end

    let(:test_mailer) { test_mailer_class.new }

    it "defines the callback methods" do
      expect(test_mailer_class).to respond_to(:before_deliver)
      expect(test_mailer_class).to respond_to(:after_deliver)
      expect(test_mailer_class).to respond_to(:around_deliver)
    end

    it "runs the callbacks in the correct order" do
      test_mailer.test_method

      expect(test_mailer.before_called).to be true
      expect(test_mailer.after_called).to be true
      expect(test_mailer.around_before_called).to be true
      expect(test_mailer.around_after_called).to be true
    end

    # Test integration with ActionMailer::MessageDelivery
    context "when integrated with ActionMailer::MessageDelivery" do
      before do
        # Define a mock MessageDelivery class to simulate Rails behavior
        ::ActionMailer.const_set(:MessageDelivery, Class.new do
          def initialize(mailer_class, action, *args)
            @mailer_class = mailer_class
            @action = action
            @args = args
          end

          def processed_mailer
            @processed_mailer ||= @mailer_class.new.tap do |mailer|
              mailer.process(@action, *@args)
            end
          end
        end)

        # Allow class_eval to be called
        allow_any_instance_of(::ActionMailer::MessageDelivery).to receive(:processed_mailer).and_return(
          double("Mailer", handle_exceptions: true, run_callbacks: true)
        )
      end

      after do
        # Clean up
        ::ActionMailer.send(:remove_const, :MessageDelivery) if defined?(::ActionMailer::MessageDelivery)
      end

      it "adds the handle_exceptions method to MessageDelivery" do
        expect(::ActionMailer::MessageDelivery.instance_methods).to include(:handle_exceptions)
      end

      it "calls run_callbacks on the processed mailer" do
        delivery = ::ActionMailer::MessageDelivery.new(test_mailer_class, :test_method)
        mailer = delivery.processed_mailer

        expect(mailer).to receive(:run_callbacks).with(:deliver)
        delivery.handle_exceptions
      end
    end
  end

  describe ".patch_message_delivery" do
    before do
      # Create a mock MessageDelivery class for testing
      ::ActionMailer.const_set(:MessageDelivery, Class.new do
        def initialize; end
        def deliver; end
        def deliver!; end
        def processed_mailer; end
      end)

      # Allow class_eval to be called
      allow_any_instance_of(::ActionMailer::MessageDelivery).to receive(:processed_mailer).and_return(
        double("Mailer", handle_exceptions: true, run_callbacks: true)
      )
    end

    after do
      # Clean up
      ::ActionMailer.send(:remove_const, :MessageDelivery) if defined?(::ActionMailer::MessageDelivery)
    end

    it "patches MessageDelivery with deliver_now and deliver_now! methods" do
      # Apply the patch
      described_class.patch_message_delivery

      # Create a new instance
      message_delivery = ::ActionMailer::MessageDelivery.new

      # Verify the methods were patched
      expect(message_delivery).to respond_to(:deliver_now)
      expect(message_delivery).to respond_to(:deliver_now!)
    end
  end
end
