# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  class ConfigurationTest < ActiveSupport::TestCase
    # Stands in for GoodJob::CLI (GoodJob isn't installed for the tests)
    class FakeGoodJobCLI
      class << self
        attr_accessor :within_exe
        alias_method :within_exe?, :within_exe
      end
    end

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

    def test_enabled_environments_set_in_an_initializer_apply
      ClimateControl.modify LOGSTRUCT_ENABLED: nil do
        Rails.stub(:env, ActiveSupport::StringInquirer.new("test")) do
          LogStruct.config.enabled_environments = [:test, :production]
          LogStruct.set_enabled_from_rails_env!

          LogStruct.config.enabled_environments = [:production]
          LogStruct.apply_initializer_settings!

          refute LogStruct.config.enabled
        end
      end
    end

    def test_enabled_set_in_an_initializer_wins_over_enabled_environments
      ClimateControl.modify LOGSTRUCT_ENABLED: nil do
        Rails.stub(:env, ActiveSupport::StringInquirer.new("test")) do
          LogStruct.config.enabled_environments = [:production]
          LogStruct.set_enabled_from_rails_env!

          LogStruct.config.enabled = true
          LogStruct.config.enabled_environments = [:staging]
          LogStruct.apply_initializer_settings!

          assert LogStruct.config.enabled
        end
      end
    end

    def test_logstruct_enabled_wins_over_settings_from_an_initializer
      ClimateControl.modify LOGSTRUCT_ENABLED: "true" do
        Rails.stub(:env, ActiveSupport::StringInquirer.new("test")) do
          LogStruct.set_enabled_from_rails_env!

          LogStruct.config.enabled = false
          LogStruct.config.enabled_environments = [:production]
          LogStruct.apply_initializer_settings!

          assert LogStruct.config.enabled
        end
      end
    end

    def test_merge_rails_filter_parameters_matches_keys_the_way_rails_does
      filter_params = [:passw, "Card_Number", :_key]

      with_rails_filter_parameters(filter_params) do
        LogStruct.merge_rails_filter_parameters!
      end

      %w[password new_PASSWORD card_number_last4 stripe_key].each do |key|
        assert ParamFilters.should_filter_key?(key), "#{key} should be filtered"
      end
      %w[name keyboard].each do |key|
        refute ParamFilters.should_filter_key?(key), "#{key} should not be filtered"
      end
      # Rails keeps its own list for filtered_parameters, filter_attributes, etc.
      assert_equal [:passw, "Card_Number", :_key], filter_params
    end

    def test_merge_rails_filter_parameters_preserves_regex_filters
      regex_filter = /\Aapi_/i
      filter_params = [regex_filter]

      with_rails_filter_parameters(filter_params) do
        LogStruct.merge_rails_filter_parameters!
      end

      assert ParamFilters.should_filter_key?("api_token"), "regex-based Rails filters should continue filtering keys"
      refute ParamFilters.should_filter_key?("rapid_api_value")
      assert_equal [regex_filter], filter_params
    end

    def test_merge_rails_filter_parameters_again_uses_the_latest_list
      with_rails_filter_parameters([:first_word]) { LogStruct.merge_rails_filter_parameters! }
      with_rails_filter_parameters([:second_word]) { LogStruct.merge_rails_filter_parameters! }

      assert ParamFilters.should_filter_key?("second_word_count")
      refute ParamFilters.should_filter_key?("first_word_count")
    end

    def test_rails_partial_matches_skip_logstruct_fields
      with_rails_filter_parameters([:_key, :metadata]) do
        LogStruct.merge_rails_filter_parameters!
      end

      log_line = Formatter.new.call(::Logger::INFO,
        Time.now,
        nil,
        {msg: "Stored", cron_key: "daily_cleanup", metadata: {size: 1}, data: {stripe_key: "sk_live_123"}})

      result = JSON.parse(log_line)
      # Rails' :_key would filter GoodJob's cron_key
      assert_equal "daily_cleanup", result["cron_key"]
      # Exact names still filter LogStruct's own fields
      assert result["metadata"].key?("_filtered"), "metadata should be filtered: #{log_line}"
      assert_not_includes log_line, "sk_live_123"
    end

    def test_rails_filter_blocks_get_a_copy_of_the_value
      reverse_secrets = ->(key, value) { value.reverse! if key.include?("answer") }
      value = +"blue"

      with_rails_filter_parameters([reverse_secrets]) do
        LogStruct.merge_rails_filter_parameters!
      end

      assert ParamFilters.should_filter_key?("security_answer", value)
      assert_equal "blue", value
    end

    def test_rails_regexps_filter_logstruct_fields_too
      with_rails_filter_parameters([/\Adata\z/, :_key]) do
        LogStruct.merge_rails_filter_parameters!
      end

      log_line = Formatter.new.call(::Logger::INFO, Time.now, nil, {msg: "Stored", cron_key: "daily", data: {note: "regexp-secret"}})

      assert_not_includes log_line, "regexp-secret"
      assert JSON.parse(log_line)["data"].key?("_filtered"), "data should be filtered: #{log_line}"
      # The partial match still skips LogStruct's own fields
      assert_equal "daily", JSON.parse(log_line)["cron_key"]
    end

    def test_rails_filter_blocks_that_replace_the_value_filter_it
      # Rails ignores a block's return value and logs the value as the block left it
      mask_notes = ->(key, value) {
        value.replace("[FILTERED]") if key == "private_note" && value.is_a?(String)
        nil
      }
      value = +"block-secret"

      with_rails_filter_parameters([mask_notes]) do
        LogStruct.merge_rails_filter_parameters!
      end

      assert ParamFilters.should_filter_key?("private_note", value)
      refute ParamFilters.should_filter_key?("public_note", +"hello")
      assert_equal "block-secret", value
      log_line = Formatter.new.call(::Logger::INFO, Time.now, nil, {msg: "Saved", private_note: +"block-secret"})

      assert_not_includes log_line, "block-secret"
    end

    def test_rails_filter_blocks_with_three_arguments
      pin_filter = ->(key, _value, _params) { key == "pin" }

      with_rails_filter_parameters([pin_filter]) do
        LogStruct.merge_rails_filter_parameters!
      end

      assert ParamFilters.should_filter_key?("pin", "1234")
      refute ParamFilters.should_filter_key?("name", "Ada")
    end

    # Test that development server process is DISABLED by default
    # (development is not in enabled_environments by default)
    def test_disabled_for_development_server_with_default_environments
      LogStruct.config.enabled = true
      # Use default enabled_environments: [:test, :production]
      LogStruct.config.enabled_environments = [:test, :production]

      original_argv = ::ARGV.dup
      ::ARGV.replace(["server"])

      Rails.stub(:env, ActiveSupport::StringInquirer.new("development")) do
        LogStruct.set_enabled_from_rails_env!

        assert_not LogStruct.config.enabled,
          "LogStruct should be DISABLED for development server (development not in enabled_environments)"
      end
    ensure
      ::ARGV.replace(original_argv) if defined?(original_argv)
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

    def test_enabled_for_good_job_executable_in_production
      original_server_mode = LogStruct.server_mode?
      had_rails_server = defined?(::Rails::Server)
      LogStruct.server_mode = false
      ::Rails.send(:remove_const, :Server) if defined?(::Rails::Server)
      LogStruct.config.enabled = false
      LogStruct.config.enabled_environments = [:production]

      # GoodJob loads its CLI class in every process; only its executable sets within_exe
      raise "GoodJob is loaded in the tests, so this test can't stand in for it" if defined?(::GoodJob)
      FakeGoodJobCLI.within_exe = nil
      Object.const_set(:GoodJob, Module.new)
      ::GoodJob.const_set(:CLI, FakeGoodJobCLI)

      Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
        LogStruct.set_enabled_from_rails_env!

        assert_not LogStruct.config.enabled, "LogStruct should stay disabled when GoodJob is loaded outside its executable"

        FakeGoodJobCLI.within_exe = true
        LogStruct.set_enabled_from_rails_env!

        assert LogStruct.config.enabled, "LogStruct should be enabled in GoodJob's executable in production"
      end
    ensure
      LogStruct.server_mode = T.must(original_server_mode)
      ::Rails.const_set(:Server, Class.new) if had_rails_server && !defined?(::Rails::Server)
      Object.send(:remove_const, :GoodJob) if defined?(::GoodJob)
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

    def test_enabled_for_test_runs
      LogStruct.config.enabled = false
      LogStruct.config.enabled_environments = [:test]

      # Test environment always enables JSON logging (both local and CI)
      ClimateControl.modify CI: nil do
        Rails.stub(:env, ActiveSupport::StringInquirer.new("test")) do
          LogStruct.set_enabled_from_rails_env!

          assert LogStruct.config.enabled, "LogStruct should be enabled for all test runs"
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

    def test_enabled_regardless_of_ci_value
      LogStruct.config.enabled = false
      LogStruct.config.enabled_environments = [:test]

      # Test environment enables JSON logging regardless of CI value
      ClimateControl.modify CI: "false" do
        Rails.stub(:env, ActiveSupport::StringInquirer.new("test")) do
          LogStruct.set_enabled_from_rails_env!

          assert LogStruct.config.enabled, "LogStruct should be enabled in test environment regardless of CI value"
        end
      end
    end

    def test_disabled_for_rake_tasks_in_production
      original_server_mode = LogStruct.server_mode?
      had_rails_server = defined?(::Rails::Server)

      # Reset all server detection state (might be set by other tests)
      LogStruct.server_mode = false
      ::Rails.send(:remove_const, :Server) if defined?(::Rails::Server)

      LogStruct.config.enabled = false
      LogStruct.config.enabled_environments = [:production]

      # No Rails::Server, no Rails::Console, not test env - this simulates a rake task
      Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
        LogStruct.set_enabled_from_rails_env!

        assert_not LogStruct.config.enabled, "LogStruct should be disabled for rake tasks in production"
      end
    ensure
      LogStruct.server_mode = T.must(original_server_mode)
      # Restore Rails::Server if it was defined before
      ::Rails.const_set(:Server, Class.new) if had_rails_server && !defined?(::Rails::Server)
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

      # Test that empty string CI value still enables in test environment
      ClimateControl.modify CI: "" do
        Rails.stub(:env, ActiveSupport::StringInquirer.new("test")) do
          LogStruct.set_enabled_from_rails_env!

          assert LogStruct.config.enabled, "Test environment should be enabled regardless of CI value"
        end
      end
    end

    # Test puma detection via ARGV when running through wrapper scripts (e.g., gosu)
    # In this scenario, $PROGRAM_NAME is the wrapper (e.g., /usr/bin/gosu) but ARGV
    # contains "puma" arguments like: ["deploy", "puma", "-C", "config/puma.rb"]
    def test_enabled_for_puma_via_argv_in_production
      original_server_mode = LogStruct.server_mode?
      had_rails_server = defined?(::Rails::Server)

      # Reset all server detection state
      LogStruct.server_mode = false
      ::Rails.send(:remove_const, :Server) if defined?(::Rails::Server)

      LogStruct.config.enabled = false
      LogStruct.config.enabled_environments = [:production]

      # Simulate gosu wrapper: ARGV contains puma arguments but $PROGRAM_NAME is gosu
      original_argv = ::ARGV.dup
      ::ARGV.replace(["deploy", "puma", "-C", "config/puma.rb"])

      Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
        LogStruct.set_enabled_from_rails_env!

        assert LogStruct.config.enabled,
          "LogStruct should be enabled when puma is detected via ARGV (gosu wrapper scenario)"
      end
    ensure
      ::ARGV.replace(original_argv) if defined?(original_argv)
      LogStruct.server_mode = T.must(original_server_mode)
      ::Rails.const_set(:Server, Class.new) if had_rails_server && !defined?(::Rails::Server)
    end

    private

    def with_rails_filter_parameters(filter_params, &block)
      mock_config = T.unsafe(Object.new)
      mock_config.define_singleton_method(:filter_parameters) { filter_params }
      mock_app = T.unsafe(Object.new)
      mock_app.define_singleton_method(:config) { mock_config }
      LogStruct.config.filters.filter_keys = []

      Rails.stub(:application, mock_app, &block)
    end
  end
end
