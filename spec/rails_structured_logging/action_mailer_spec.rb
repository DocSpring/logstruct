# typed: false
# frozen_string_literal: true

require "spec_helper"
require "rails"
require "action_mailer"
require "active_support"

RSpec.describe RailsStructuredLogging::ActionMailer do
  describe ".setup" do
    before do
      # Reset configuration for each test
      allow(RailsStructuredLogging).to receive_messages(enabled?: true,
        configuration: double(
          "Configuration", actionmailer_integration_enabled: true
        ))

      # Allow logger to be set
      allow(ActionMailer::Base).to receive(:logger=)

      # Allow include to be called
      allow(ActionMailer::Base).to receive(:include)

      # For Rails 7.0 callback setup
      allow(described_class).to receive(:setup_callbacks_for_rails_7_0) if Rails.gem_version < Gem::Version.new("7.1.0")
    end

    it "sets up ActionMailer integration" do
      # Expect ::ActionMailer::Base to be configured with a null logger
      expect(ActionMailer::Base).to receive(:logger=)

      # Expect ::ActionMailer::Base to include our module
      expect(ActionMailer::Base).to receive(:include).with(described_class)

      # Expect callbacks to be set up for Rails 7.0 if needed
      if Rails.gem_version < Gem::Version.new("7.1.0")
        expect(described_class).to receive(:setup_callbacks_for_rails_7_0)
      end

      described_class.setup
    end

    context "when structured logging is disabled" do
      before do
        allow(RailsStructuredLogging).to receive(:enabled?).and_return(false)
      end

      it "returns early without setting up" do
        expect(ActionMailer::Base).not_to receive(:logger=)
        expect(ActionMailer::Base).not_to receive(:include)

        described_class.setup
      end
    end

    context "when ActionMailer integration is disabled" do
      before do
        allow(RailsStructuredLogging).to receive(:configuration).and_return(
          double("Configuration", actionmailer_integration_enabled: false)
        )
      end

      it "returns early without setting up" do
        expect(ActionMailer::Base).not_to receive(:logger=)
        expect(ActionMailer::Base).not_to receive(:include)

        described_class.setup
      end
    end
  end

  describe ".setup_callbacks_for_rails_7_0", if: Rails.gem_version < Gem::Version.new("7.1.0") do
    before do
      # Allow ActiveSupport.on_load to work
      allow(ActiveSupport).to receive(:on_load).and_yield

      # Allow ::ActionMailer::Base to include modules
      allow(ActionMailer::Base).to receive(:include)

      # Allow Callbacks module to patch MessageDelivery
      allow(RailsStructuredLogging::ActionMailer::Callbacks).to receive(:patch_message_delivery)
    end

    it "includes Callbacks module and patches MessageDelivery" do
      expect(ActionMailer::Base).to receive(:include).with(RailsStructuredLogging::ActionMailer::Callbacks)
      expect(RailsStructuredLogging::ActionMailer::Callbacks).to receive(:patch_message_delivery)

      described_class.send(:setup_callbacks_for_rails_7_0)
    end
  end
end
