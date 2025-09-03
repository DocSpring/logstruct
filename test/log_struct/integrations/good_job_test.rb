# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  module Integrations
    class GoodJobTest < ActiveSupport::TestCase
      setup do
        @original_config = LogStruct.config
        LogStruct.configuration = LogStruct::Configuration.new
        LogStruct.config.enabled = true
        LogStruct.config.integrations.enable_goodjob = true
      end

      teardown do
        LogStruct.configuration = @original_config
      end

      test "responds to setup method" do
        assert_respond_to GoodJob, :setup
      end

      test "implements IntegrationInterface" do
        assert_includes GoodJob.singleton_class.included_modules, IntegrationInterface
      end

      test "returns early when GoodJob is not defined" do
        # Mock GoodJob as not being defined
        skip_if_goodjob_defined do
          result = GoodJob.setup(LogStruct.config)

          assert_nil result
        end
      end

      test "returns early when LogStruct is disabled" do
        skip_if_goodjob_defined do
          LogStruct.config.enabled = false
          result = GoodJob.setup(LogStruct.config)

          assert_nil result
        end
      end

      test "returns early when GoodJob integration is disabled" do
        skip_if_goodjob_defined do
          LogStruct.config.integrations.enable_goodjob = false
          result = GoodJob.setup(LogStruct.config)

          assert_nil result
        end
      end

      test "configure_logger method exists and is private" do
        assert_includes GoodJob.private_methods, :configure_logger
      end

      test "subscribe_to_notifications method exists and is private" do
        assert_includes GoodJob.private_methods, :subscribe_to_notifications
      end

      test "integration is included in automatic setup" do
        # Check that GoodJob is required in integrations.rb
        integrations_file = File.read(
          File.join(__dir__, "../../../lib/log_struct/integrations.rb")
        )

        assert_includes integrations_file, 'require_relative "integrations/good_job"'

        # Check that setup is called conditionally
        assert_includes integrations_file,
          "Integrations::GoodJob.setup(config) if config.integrations.enable_goodjob"
      end

      test "configuration option exists" do
        assert_respond_to LogStruct.config.integrations, :enable_goodjob
        assert LogStruct.config.integrations.enable_goodjob
      end

      private

      def skip_if_goodjob_defined
        if defined?(::GoodJob)
          skip "GoodJob is defined in test environment - cannot test undefined behavior"
        else
          yield
        end
      end
    end
  end
end
