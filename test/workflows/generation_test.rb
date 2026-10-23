# typed: true
# frozen_string_literal: true

require "test_helper"
require "digest"
require "open3"
require "tmpdir"

module LogStruct
  class GenerationTest < ActiveSupport::TestCase
    ROOT = File.expand_path("../..", __dir__)

    LOAD_GENERATORS = <<~RUBY
      require "bundler/setup"
      require "sorbet-runtime"
      $LOAD_PATH.unshift(File.expand_path("lib"))
      require "log_struct/enums"
      require_relative "tools/codegen/sorbet_generator"
      require_relative "tools/codegen/ts_generator"
      require_relative "tools/codegen/log_fields_generator"
    RUBY

    # Skip writes in the child process so failure checks cannot change generated files.
    STUB_GENERATORS = <<~RUBY
      LogStruct::Codegen::SorbetGenerator.define_singleton_method(:generate_all) { |root, staging| ["lib/log_struct/log/stub.rb"] }
      LogStruct::Codegen::TSGenerator.define_singleton_method(:generate_all) { |root, staging| }
      LogStruct::Codegen::LogFieldsGenerator.define_singleton_method(:generate) { |staging| }
    RUBY

    test "a failed formatter stops generation" do
      output, status = run_generator(STUB_GENERATORS + "Kernel.define_method(:system) { |*args, **opts| false }")

      refute_predicate status, :success?, output
      assert_includes output, "Failed to format generated Ruby log structs"
      assert_not_includes output, "Exporting Sorbet JSON"
    end

    test "a failed JSON export fails generation" do
      output, status = run_generator(STUB_GENERATORS + <<~RUBY)
        Kernel.define_method(:system) { |*args, **opts| true }
        require "sorbet/typescript"
        Sorbet::Typescript::Exporter.define_method(:export) { |**args| raise "intentional export failure" }
      RUBY

      refute_predicate status, :success?, output
      assert_includes output, "intentional export failure"
    end

    # `task ci` interrupts the generator when a step running beside it fails
    test "an interrupted formatter leaves the generated files as they were" do
      Dir.mktmpdir do |copy|
        %w[lib schemas scripts tools .rubocop.yml].each { |path| FileUtils.cp_r(File.join(ROOT, path), copy) }
        before = file_digests(copy)

        output, status = run_generator("Kernel.define_method(:system) { |*args, **opts| raise Interrupt }", chdir: copy)

        refute_predicate status, :success?, output
        assert_includes output, "Formatting generated Ruby code..."
        assert_includes output, "Interrupt"
        assert_equal before, file_digests(copy)
        assert_empty Dir.children(File.join(copy, "tmp"))
      end
    end

    private

    def run_generator(injection, chdir: ROOT)
      script = LOAD_GENERATORS + injection + "\nload 'scripts/generate_structs.rb'\n"
      env = {"BUNDLE_GEMFILE" => File.join(ROOT, "Gemfile")}
      Open3.capture2e(env, RbConfig.ruby, "-e", script, chdir: chdir)
    end

    def file_digests(dir)
      Dir.glob("{lib,schemas}/**/*", base: dir).select { |path| File.file?(File.join(dir, path)) }.to_h do |path|
        [path, Digest::SHA256.file(File.join(dir, path)).hexdigest]
      end
    end
  end
end
