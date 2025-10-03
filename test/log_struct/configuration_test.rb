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

    def test_set_enabled_from_rails_env_with_matching_environment_in_ci
      # Set up test conditions
      LogStruct.config.enabled = false
      LogStruct.config.enabled_environments = [:test]

      # Stub Rails.env to match enabled_environments AND set CI=true
      ClimateControl.modify CI: "true" do
        Rails.stub(:env, ActiveSupport::StringInquirer.new("test")) do
          LogStruct.set_enabled_from_rails_env!

          assert LogStruct.config.enabled, "LogStruct should be enabled in test environment when CI=true"
        end
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

    def test_set_enabled_from_env_var_when_no
      # Set up test conditions
      LogStruct.config.enabled = true
      LogStruct.config.enabled_environments = [] # No environments enabled

      # Use ClimateControl to modify ENV
      ClimateControl.modify LOGSTRUCT_ENABLED: "no" do
        # Stub Rails.env to not match enabled_environments
        Rails.stub(:env, ActiveSupport::StringInquirer.new("development")) do
          LogStruct.set_enabled_from_rails_env!

          assert_not LogStruct.config.enabled, 'LogStruct should be disabled when LOGSTRUCT_ENABLED is "no"'
        end
      end
    end

    def test_enabled_env_var_takes_precedence_over_environment
      # Set up test conditions
      LogStruct.config.enabled = false
      LogStruct.config.enabled_environments = [:test] # Test environment is enabled

      # Use ClimateControl to modify ENV
      ClimateControl.modify LOGSTRUCT_ENABLED: "false" do
        # Stub Rails.env to match enabled_environments
        Rails.stub(:env, ActiveSupport::StringInquirer.new("test")) do
          LogStruct.set_enabled_from_rails_env!

          refute LogStruct.config.enabled, "Env var should take precedence over environment"
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

    def test_merge_rails_filter_parameters_preserves_regex_filters
      original_filter_keys = LogStruct.config.filters.filter_keys.dup
      original_matchers = LogStruct.config.filters.filter_matchers.dup

      regex_filter = /\Aapi_/i
      filter_params = [regex_filter]

      filter_params.define_singleton_method(:clear) do
        replace([])
      end

      mock_config = T.unsafe(Object.new)
      mock_config.define_singleton_method(:filter_parameters) { filter_params }
      mock_config.define_singleton_method(:respond_to?) do |method_name, include_private = false|
        if method_name.to_sym == :filter_parameters
          true
        else
          super(method_name, include_private)
        end
      end

      mock_app = T.unsafe(Object.new)
      mock_app.define_singleton_method(:config) { mock_config }

      LogStruct.config.filters.filter_keys = []

      Rails.stub(:application, mock_app) do
        LogStruct.merge_rails_filter_parameters!
      end

      assert ParamFilters.should_filter_key?("api_token"), "regex-based Rails filters should continue filtering keys"
    ensure
      LogStruct.config.filters.filter_keys = original_filter_keys
      LogStruct.config.filters.filter_matchers = original_matchers
    end

    # Test server process detection
    def test_enabled_for_server_process_in_production
      LogStruct.config.enabled = false
      LogStruct.config.enabled_environments = [:production]

      # Define Rails::Server to simulate server process
      rails_server_class = Class.new
      Object.const_set(:Rails, Module.new) unless defined?(::Rails)
      ::Rails.const_set(:Server, rails_server_class) unless defined?(::Rails::Server)

      original_argv = ::ARGV.dup
      ::ARGV.replace(["server"])

      Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
        LogStruct.set_enabled_from_rails_env!

        assert LogStruct.config.enabled, "LogStruct should be enabled for server process in production"
      end
    ensure
      ::ARGV.replace(original_argv) if defined?(original_argv)
      ::Rails.send(:remove_const, :Server) if defined?(::Rails::Server)
    end

    def test_disabled_for_console_in_production
      LogStruct.config.enabled = false
      LogStruct.config.enabled_environments = [:production]

      # Define Rails::Console to simulate console process
      rails_console_class = Class.new
      Object.const_set(:Rails, Module.new) unless defined?(::Rails)
      ::Rails.const_set(:Console, rails_console_class) unless defined?(::Rails::Console)

      Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
        LogStruct.set_enabled_from_rails_env!

        assert_not LogStruct.config.enabled, "LogStruct should be disabled for console in production"
      end
    ensure
      ::Rails.send(:remove_const, :Console) if defined?(::Rails::Console)
    end

    def test_disabled_for_local_test_runs
      LogStruct.config.enabled = false
      LogStruct.config.enabled_environments = [:test]

      # No CI env var, no Rails::Server, no Rails::Console
      ClimateControl.modify CI: nil do
        Rails.stub(:env, ActiveSupport::StringInquirer.new("test")) do
          LogStruct.set_enabled_from_rails_env!

          assert_not LogStruct.config.enabled, "LogStruct should be disabled for local test runs"
        end
      end
    end

    def test_enabled_for_ci_test_runs
      LogStruct.config.enabled = false
      LogStruct.config.enabled_environments = [:test]

      # CI=true should enable for test runs
      ClimateControl.modify CI: "true" do
        Rails.stub(:env, ActiveSupport::StringInquirer.new("test")) do
          LogStruct.set_enabled_from_rails_env!

          assert LogStruct.config.enabled, "LogStruct should be enabled for CI test runs"
        end
      end
    end

    def test_ci_false_treated_as_not_ci
      LogStruct.config.enabled = false
      LogStruct.config.enabled_environments = [:test]

      # CI=false should be treated as not CI
      ClimateControl.modify CI: "false" do
        Rails.stub(:env, ActiveSupport::StringInquirer.new("test")) do
          LogStruct.set_enabled_from_rails_env!

          assert_not LogStruct.config.enabled, "LogStruct should be disabled when CI=false"
        end
      end
    end

    def test_disabled_for_rake_tasks_in_production
      LogStruct.config.enabled = false
      LogStruct.config.enabled_environments = [:production]

      # No Rails::Server, no Rails::Console, not test env
      Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
        LogStruct.set_enabled_from_rails_env!

        assert_not LogStruct.config.enabled, "LogStruct should be disabled for rake tasks in production"
      end
    end

    def test_logstruct_enabled_overrides_all_logic
      LogStruct.config.enabled = false
      LogStruct.config.enabled_environments = []

      # Even with console defined and no enabled environments, LOGSTRUCT_ENABLED=true should enable
      rails_console_class = Class.new
      Object.const_set(:Rails, Module.new) unless defined?(::Rails)
      ::Rails.const_set(:Console, rails_console_class) unless defined?(::Rails::Console)

      ClimateControl.modify LOGSTRUCT_ENABLED: "true" do
        Rails.stub(:env, ActiveSupport::StringInquirer.new("development")) do
          LogStruct.set_enabled_from_rails_env!

          assert LogStruct.config.enabled, "LOGSTRUCT_ENABLED=true should override all other logic"
        end
      end
    ensure
      ::Rails.send(:remove_const, :Console) if defined?(::Rails::Console)
    end

    def test_console_disabled_even_in_ci
      LogStruct.config.enabled = false
      LogStruct.config.enabled_environments = [:test]

      # Console should be disabled even in CI
      rails_console_class = Class.new
      Object.const_set(:Rails, Module.new) unless defined?(::Rails)
      ::Rails.const_set(:Console, rails_console_class) unless defined?(::Rails::Console)

      ClimateControl.modify CI: "true" do
        Rails.stub(:env, ActiveSupport::StringInquirer.new("test")) do
          LogStruct.set_enabled_from_rails_env!

          assert_not LogStruct.config.enabled, "Console should be disabled even in CI"
        end
      end
    ensure
      ::Rails.send(:remove_const, :Console) if defined?(::Rails::Console)
    end

    def test_various_ci_env_values
      LogStruct.config.enabled = false
      LogStruct.config.enabled_environments = [:test]

      # Test various truthy CI values
      %w[true 1 yes].each do |ci_value|
        ClimateControl.modify CI: ci_value do
          Rails.stub(:env, ActiveSupport::StringInquirer.new("test")) do
            LogStruct.set_enabled_from_rails_env!

            assert LogStruct.config.enabled, "CI=#{ci_value} should enable LogStruct in test"
          end
        end

        # Reset for next iteration
        LogStruct.config.enabled = false
      end

      # Test that empty string is treated as CI not set
      ClimateControl.modify CI: "" do
        Rails.stub(:env, ActiveSupport::StringInquirer.new("test")) do
          LogStruct.set_enabled_from_rails_env!

          assert_not LogStruct.config.enabled, "CI='' (empty string) should be treated as not CI"
        end
      end
    end
  end
end
