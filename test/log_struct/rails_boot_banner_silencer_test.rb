# typed: true
# frozen_string_literal: true

require "test_helper"

class RailsBootBannerSilencerTest < Minitest::Test
  SILENCER = LogStruct::RailsBootBannerSilencer
  SERVER_MODULE = LogStruct::RailsBootBannerSilencer::ServerCommandSilencer

  def setup
    @original_argv = ARGV.dup
    @installed_flag = SILENCER.instance_variable_get(:@installed)
    SILENCER.instance_variable_set(:@installed, false)
    store_server_mode
  end

  def teardown
    ARGV.replace(@original_argv)
    SILENCER.instance_variable_set(:@installed, @installed_flag)
    restore_server_mode
  end

  def test_install_skips_patch_when_not_running_server
    ARGV.replace(["console"])

    SILENCER.stub(:patch!, proc { flunk("patch! should not run without server arg") }) do
      SILENCER.install!
    end
  end

  def test_patch_handles_missing_rails_gracefully
    with_kernel_require_raising_load_error do
      SILENCER.instance_variable_set(:@installed, false)
      ARGV.replace(["server"])

      refute(SILENCER.patch!)
    end
  end

  def test_patch_patches_when_server_command_is_available
    stub_class = build_server_command_stub
    ARGV.replace(["server"])

    stub_const_get(stub_class) do
      assert(SILENCER.patch!)
    end

    assert_includes(stub_class.ancestors, SERVER_MODULE)
  end

  def test_patch_server_command_is_idempotent
    stub_class = build_server_command_stub
    SILENCER.patch_server_command(stub_class)
    first_count = count_silencer_modules(stub_class)
    SILENCER.patch_server_command(stub_class)

    assert_equal(first_count, count_silencer_modules(stub_class))
  end

  def test_perform_marks_server_mode_and_delegates
    stub_class = build_server_command_stub
    SILENCER.patch_server_command(stub_class)

    instance = stub_class.new
    result = instance.perform(:foo, :bar)

    assert_equal(:original_perform, result)
    assert_equal([:foo, :bar], instance.performed_args)
    assert_predicate(LogStruct, :server_mode?)
  end

  def test_print_boot_information_consumes_banner_lines
    stub_class = build_server_command_stub
    SILENCER.patch_server_command(stub_class)
    instance = stub_class.new

    processed = []
    boot_called = false

    LogStruct::Integrations::Puma.stub(:emit_boot_if_needed!, proc { boot_called = true }) do
      LogStruct::Integrations::Puma.stub(:process_line, ->(line) { processed << line }) do
        Rails.stub(:version, "8.0.1") do
          Rails.stub(:env, "test") do
            instance.print_boot_information("Stub::Server", "http://localhost:3000")
          end
        end
      end
    end

    assert(boot_called)
    assert_includes(processed, "=> Booting Server")
    assert_includes(processed, "=> Rails 8.0.1 application starting in test http://localhost:3000")
    assert_includes(processed, "=> Run `task-cli --help` for more startup options")
  end

  def test_print_boot_information_uses_fallbacks
    stub_class = build_server_command_stub(executable: proc { raise "missing" })
    SILENCER.patch_server_command(stub_class)
    instance = stub_class.new
    processed = []

    LogStruct::Integrations::Puma.stub(:emit_boot_if_needed!, proc {}) do
      LogStruct::Integrations::Puma.stub(:process_line, ->(line) { processed << line }) do
        ActiveSupport::Inflector.stub(:demodulize, proc { raise "boom" }) do
          Rails.stub(:version, proc { raise "no version" }) do
            instance.print_boot_information(Object.new, nil)
          end
        end
      end
    end

    assert_includes(processed, "=> Booting Puma")
    assert_includes(processed, "=> Rails application starting")
    assert_includes(processed, "=> Run `rails --help` for more startup options")
  end

  def test_lookup_executable_returns_default_when_missing
    klass = Class.new do
      prepend SERVER_MODULE

      def perform(*)
      end

      def print_boot_information(_server, _url)
      end
    end

    value = klass.new.send(:lookup_executable)

    assert_equal("rails", value)
  end

  private

  def store_server_mode
    @stored_server_mode = LogStruct.server_mode?
    LogStruct.server_mode = false
  end

  def restore_server_mode
    LogStruct.server_mode = @stored_server_mode
  end

  def build_server_command_stub(executable: "task-cli")
    Class.new do
      class << self
        attr_reader :prepended_modules

        def prepend(mod)
          (@prepended_modules ||= []) << mod
          super
        end
      end

      attr_reader :performed_args

      define_method(:perform) do |*args|
        @performed_args = args
        :original_perform
      end

      define_method(:print_boot_information) do |_server, _url|
        :original_print
      end

      define_method(:executable) do
        executable.is_a?(Proc) ? executable.call : executable
      end
    end
  end

  def stub_const_get(stub_class)
    original_const_get = Object.method(:const_get)

    Object.stub(:const_get,
      ->(name, inherit = true) do
        if name == "Rails::Command::ServerCommand"
          stub_class
        else
          original_const_get.call(name, inherit)
        end
      end) do
      yield
    end
  end

  def count_silencer_modules(stub_class)
    stub_class.singleton_class.ancestors.count { |ancestor| ancestor == SERVER_MODULE }
  end

  def with_kernel_require_raising_load_error
    kernel_singleton = Kernel.singleton_class
    kernel_module = Kernel

    kernel_module.class_eval do
      alias_method :__logstruct_original_instance_require, :require
      define_method(:require) do |*_args|
        raise LoadError, "missing"
      end
    end
    kernel_singleton.class_eval do
      alias_method :__logstruct_original_module_require, :require
      define_method(:require) do |*_args|
        raise LoadError, "missing"
      end
    end
    yield
  ensure
    kernel_module.class_eval do
      remove_method :require
      alias_method :require, :__logstruct_original_instance_require
      remove_method :__logstruct_original_instance_require
    end
    kernel_singleton.class_eval do
      remove_method :require
      alias_method :require, :__logstruct_original_module_require
      remove_method :__logstruct_original_module_require
    end
  end
end
