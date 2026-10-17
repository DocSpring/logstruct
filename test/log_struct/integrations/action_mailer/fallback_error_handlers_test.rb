# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  module Integrations
    module ActionMailer
      class FallbackErrorHandlersTest < ActiveSupport::TestCase
        setup do
          @output = StringIO.new
          @mailer = Class.new(::ActionMailer::Base) do
            include FallbackErrorHandlers
            extend FallbackErrorHandlers::ClassMethods

            rescue_from ArgumentError, with: :log_and_ignore_error

            def self.name
              "FallbackTestMailer"
            end

            def welcome
              raise ArgumentError, "bad address"
            end
          end
          @mailer.logger = ::Logger.new(@output)
        end

        test "without LogStruct, a mailer's rescue_from handlers log the error and do as their names say" do
          reported = []

          ::Rails.error.stub(:report, ->(error, handled:, source:) { reported << [error.message, handled, source] }) do
            @mailer.welcome.message
            @mailer.new.log_and_report_error(RuntimeError.new("report me"))
            assert_raises(RuntimeError) { @mailer.log_and_reraise_error(RuntimeError.new("retry me")) }
          end

          assert_includes @output.string, "ArgumentError: bad address"
          assert_includes @output.string, "RuntimeError: retry me"
          assert_equal [["report me", true, "logstruct.action_mailer"]], reported
        end

        test "they're added only where LogStruct doesn't set up ActionMailer" do
          hooks = []
          enabled = LogStruct::Configuration.new(enabled: true)
          disabled = LogStruct::Configuration.new(enabled: false)
          integration_off = LogStruct::Configuration.new(enabled: true)
          integration_off.integrations.enable_actionmailer = false

          ActiveSupport.stub(:on_load, ->(name, &_block) { hooks << name }) do
            [enabled, disabled, integration_off].each { |config| Integrations::ActionMailer.setup_fallback_error_handlers(config) }
          end

          assert_equal %i[action_mailer action_mailer], hooks
        end
      end
    end
  end
end
