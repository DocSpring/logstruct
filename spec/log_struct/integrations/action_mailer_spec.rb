# typed: true
# frozen_string_literal: true

require "spec_helper"

module LogStruct
  module Integrations
    RSpec.describe ActionMailer do
      describe ".setup" do
        before do
          # Reset configuration for each test
          allow(LogStruct).to receive_messages(enabled?: true,
            configuration: double(
              "Configuration", actionmailer_integration_enabled: true
            ))

          # Allow logger to be set
          allow(::ActionMailer::Base).to receive(:logger=)

          # Allow include to be called
          allow(::ActionMailer::Base).to receive(:include)

          # For Rails 7.0 callback setup
          allow(Integrations::ActionMailer).to receive(:setup_callbacks_for_rails_7_0) if Rails.gem_version < Gem::Version.new("7.1.0")
        end

        it "sets up ActionMailer integration" do
          # Expect ::ActionMailer::Base to be configured with a null logger
          expect(::ActionMailer::Base).to receive(:logger=)

          # Expect ::ActionMailer::Base to include our module
          expect(::ActionMailer::Base).to receive(:include).with(Integrations::ActionMailer)

          # Expect callbacks to be set up for Rails 7.0 if needed
          if Rails.gem_version < Gem::Version.new("7.1.0")
            expect(Integrations::ActionMailer).to receive(:setup_callbacks_for_rails_7_0)
          end

          Integrations::ActionMailer.setup
        end

        context "when structured logging is disabled" do
          before do
            allow(LogStruct).to receive(:enabled?).and_return(false)
          end

          it "returns early without setting up" do
            expect(::ActionMailer::Base).not_to receive(:logger=)
            expect(::ActionMailer::Base).not_to receive(:include)

            Integrations::ActionMailer.setup
          end
        end

        context "when ActionMailer integration is disabled" do
          before do
            allow(LogStruct).to receive(:configuration).and_return(
              double("Configuration", actionmailer_integration_enabled: false)
            )
          end

          it "returns early without setting up" do
            expect(::ActionMailer::Base).not_to receive(:logger=)
            expect(::ActionMailer::Base).not_to receive(:include)

            Integrations::ActionMailer.setup
          end
        end
      end

      describe ".setup_callbacks_for_rails_7_0", if: Rails.gem_version < Gem::Version.new("7.1.0") do
        before do
          # Allow ActiveSupport.on_load to work
          allow(::ActiveSupport).to receive(:on_load).and_yield

          # Allow ::ActionMailer::Base to include modules
          allow(::ActionMailer::Base).to receive(:include)

          # Allow Callbacks module to patch MessageDelivery
          allow(Integrations::ActionMailer::Callbacks).to receive(:patch_message_delivery)
        end

        it "includes Callbacks module and patches MessageDelivery" do
          expect(::ActionMailer::Base).to receive(:include).with(Integrations::ActionMailer::Callbacks)
          expect(Integrations::ActionMailer::Callbacks).to receive(:patch_message_delivery)

          Integrations::ActionMailer.send(:setup_callbacks_for_rails_7_0)
        end
      end
    end
  end
end
