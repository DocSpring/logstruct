# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  class ConfigurationTest < ActiveSupport::TestCase
    setup do
      # Save original configuration
      @original_config = LogStruct.config.dup
    end

    teardown do
      # Restore original configuration
      LogStruct.configuration = @original_config
    end

    def test_set_enabled_from_rails_env_with_matching_environment
      # Set up test conditions
      LogStruct.config.enabled = false
      LogStruct.config.enabled_environments = [:test]

      # Stub Rails.env to match enabled_environments
      Rails.stub(:env, ActiveSupport::StringInquirer.new("test")) do
        LogStruct.set_enabled_from_rails_env!

        assert LogStruct.config.enabled, "LogStruct should be enabled in test environment"
      end
    end

    def test_set_enabled_from_rails_env_with_non_matching_environment
      # Set up test conditions
      LogStruct.config.enabled = true
      LogStruct.config.enabled_environments = [:production]

      # Stub Rails.env to not match enabled_environments
      Rails.stub(:env, ActiveSupport::StringInquirer.new("development")) do
        LogStruct.set_enabled_from_rails_env!

        assert_not LogStruct.config.enabled, "LogStruct should be disabled when environment doesn't match"
      end
    end

    def test_set_enabled_from_rails_env_with_empty_environments_list
      # Set up test conditions
      LogStruct.config.enabled = true
      LogStruct.config.enabled_environments = []

      # Stub Rails.env with any environment since list is empty
      Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
        # Empty list means no environments are enabled
        LogStruct.set_enabled_from_rails_env!

        assert_not LogStruct.config.enabled, "LogStruct should be disabled with empty environments list"
      end
    end
  end
end
