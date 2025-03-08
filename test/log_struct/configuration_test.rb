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

    def test_set_enabled_from_env_var_true
      # Set up test conditions
      LogStruct.config.enabled = false
      LogStruct.config.enabled_environments = [] # No environments enabled

      # Use ClimateControl to modify ENV
      ClimateControl.modify LOGSTRUCT_ENABLED: "true" do
        # Stub Rails.env to not match enabled_environments
        Rails.stub(:env, ActiveSupport::StringInquirer.new("development")) do
          LogStruct.set_enabled_from_rails_env!

          assert LogStruct.config.enabled, "LogStruct should be enabled when LOGSTRUCT_ENABLED=true"
        end
      end
    end

    def test_set_enabled_from_env_var_not_true
      # Set up test conditions
      LogStruct.config.enabled = true
      LogStruct.config.enabled_environments = [] # No environments enabled

      # Use ClimateControl to modify ENV
      ClimateControl.modify LOGSTRUCT_ENABLED: "yes" do
        # Stub Rails.env to not match enabled_environments
        Rails.stub(:env, ActiveSupport::StringInquirer.new("development")) do
          LogStruct.set_enabled_from_rails_env!

          assert_not LogStruct.config.enabled, 'LogStruct should be disabled when LOGSTRUCT_ENABLED is not "true"'
        end
      end
    end

    def test_enabled_environment_takes_precedence_over_env_var
      # Set up test conditions
      LogStruct.config.enabled = false
      LogStruct.config.enabled_environments = [:test] # Test environment is enabled

      # Use ClimateControl to modify ENV
      ClimateControl.modify LOGSTRUCT_ENABLED: "false" do
        # Stub Rails.env to match enabled_environments
        Rails.stub(:env, ActiveSupport::StringInquirer.new("test")) do
          LogStruct.set_enabled_from_rails_env!

          assert LogStruct.config.enabled, "Environment should take precedence over env var"
        end
      end
    end

    def test_merge_rails_filter_parameters
      # Store original filter keys
      original_filter_keys = LogStruct.config.filters.filter_keys.dup

      # Create a mock for Rails.application.config
      # T.unsafe is needed to work around sorbet limitations in tests
      # This is acceptable since this is just a test method
      mock_config = T.unsafe(Object.new)

      # Set up mock filter parameters with a mix of symbols and strings
      filter_params = [:credit_card, "ssn", :password, "existing_key"]
      clear_called = T.let(false, T::Boolean)

      # Define necessary methods on our mock
      mock_config.define_singleton_method(:filter_parameters) { filter_params }
      mock_config.define_singleton_method(:respond_to?) do |method_name|
        method_name.to_sym == :filter_parameters || super(method_name)
      end

      # Add a clear method to the filter_parameters array
      filter_params.define_singleton_method(:clear) do
        clear_called = true
        filter_params.replace([])
      end

      # Set up mock Rails.application
      mock_app = T.unsafe(Object.new)
      mock_app.define_singleton_method(:config) { mock_config }

      # Set our initial filter keys
      LogStruct.config.filters.filter_keys = [:existing_key, :another_key]

      # Stub Rails.application
      Rails.stub(:application, mock_app) do
        # Run the method we're testing
        LogStruct.merge_rails_filter_parameters!

        # Check that all Rails filter parameters were merged
        assert_includes LogStruct.config.filters.filter_keys, :credit_card
        assert_includes LogStruct.config.filters.filter_keys, :ssn
        assert_includes LogStruct.config.filters.filter_keys, :password
        assert_includes LogStruct.config.filters.filter_keys, :existing_key
        assert_includes LogStruct.config.filters.filter_keys, :another_key

        # Check that duplicates were removed (existing_key appears in both)
        assert_equal 1, LogStruct.config.filters.filter_keys.count(:existing_key)
        assert_equal 5, LogStruct.config.filters.filter_keys.size

        # Verify Rails filter parameters were cleared
        assert_empty filter_params
        assert clear_called, "filter_parameters.clear should have been called"
      end

      # Restore original filter keys
      LogStruct.config.filters.filter_keys = original_filter_keys
    end
  end
end
