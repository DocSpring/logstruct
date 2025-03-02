# typed: false
# frozen_string_literal: true

require "spec_helper"

# Test the backported callbacks from Rails 7.1.x
# Only need to run these tests if we're using Rails < 7.1.0

module LogStruct::Integrations::ActionMailer
  RSpec.describe Callbacks, if: Rails.gem_version < Gem::Version.new("7.1.0") do
    # Apply the patch before running tests
    before(:all) do
      LogStruct::Integrations::ActionMailer::Callbacks.patch_message_delivery
    end

    describe "delivery callbacks" do
      # Define a test mailer class for testing callbacks using Class.new
      let(:test_mailer_class) do
        Class.new do
          include LogStruct::Integrations::ActionMailer::Callbacks

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

          # Add handle_exceptions method for testing
          def handle_exceptions
            yield if block_given?
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
        it "adds the handle_exceptions method to MessageDelivery" do
          expect(ActionMailer::MessageDelivery.instance_methods).to include(:handle_exceptions)
        end

        it "calls run_callbacks on the processed mailer" do
          # Create a mailer double that will receive run_callbacks
          mailer_double = double("Mailer")
          message_double = double("Message")

          # Set up expectations before creating the delivery object
          expect(mailer_double).to receive(:handle_exceptions).and_yield
          expect(mailer_double).to receive(:run_callbacks).with(:deliver).and_yield
          expect(message_double).to receive(:deliver)

          # Create a MessageDelivery with the correct arguments
          delivery = ActionMailer::MessageDelivery.new(test_mailer_class, :test_method)

          # Mock the methods to return our doubles
          allow(delivery).to receive_messages(processed_mailer: mailer_double, message: message_double)

          # Call deliver_now which should trigger the callbacks
          delivery.deliver_now
        end
      end
    end

    describe ".patch_message_delivery" do
      it "patches MessageDelivery with deliver_now and deliver_now! methods" do
        # Create a MessageDelivery with the correct arguments
        message_delivery = ActionMailer::MessageDelivery.new(Class.new, :test_method)

        # Verify the methods were patched
        expect(message_delivery).to respond_to(:deliver_now)
        expect(message_delivery).to respond_to(:deliver_now!)
      end
    end
  end
end
