# typed: true
# frozen_string_literal: true

require "test_helper"
require "open3"

module LogStruct
  class GenerationTest < ActiveSupport::TestCase
    # Skip writes in the child process so failure checks cannot change generated files.
    SETUP = <<~RUBY
      require "bundler/setup"
      require "sorbet-runtime"
      $LOAD_PATH.unshift(File.expand_path("lib"))
      require "log_struct/enums"
      require_relative "tools/codegen/sorbet_generator"
      require_relative "tools/codegen/ts_generator"
      require_relative "tools/codegen/log_fields_generator"
      LogStruct::Codegen::SorbetGenerator.define_singleton_method(:generate_all) { |root| }
      LogStruct::Codegen::TSGenerator.define_singleton_method(:generate_all) { |root| }
      LogStruct::Codegen::LogFieldsGenerator.define_singleton_method(:generate) { |root| }
    RUBY

    test "a failed formatter stops generation" do
      output, status = run_generator("Kernel.define_method(:system) { |*args| false }")

      refute_predicate status, :success?, output
      assert_includes output, "Failed to format generated Ruby log structs"
      assert_not_includes output, "Exporting Sorbet JSON"
    end

    test "a failed JSON export fails generation" do
      output, status = run_generator(<<~RUBY)
        Kernel.define_method(:system) { |*args| true }
        require "sorbet/typescript"
        Sorbet::Typescript::Exporter.define_method(:export) { |**args| raise "intentional export failure" }
      RUBY

      refute_predicate status, :success?, output
      assert_includes output, "intentional export failure"
    end

    private

    def run_generator(injection)
      script = SETUP + injection + "\nload 'scripts/generate_structs.rb'\n"
      Open3.capture2e(RbConfig.ruby, "-e", script, chdir: File.expand_path("../..", __dir__))
    end
  end
end
