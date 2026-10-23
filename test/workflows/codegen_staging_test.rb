# typed: true
# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require_relative "../../tools/codegen/staging"

module LogStruct
  class CodegenStagingTest < ActiveSupport::TestCase
    setup do
      @root = Dir.mktmpdir
      @staging = Codegen::Staging.new(@root, File.join(@root, "tmp", "codegen"))
    end

    teardown do
      FileUtils.rm_rf(@root)
    end

    test "staged files stay out of the repository until they're installed" do
      write_file("lib/log/plain.rb", "committed")

      @staging.write("lib/log/plain.rb", "generated")

      assert_equal "committed", File.read(File.join(@root, "lib/log/plain.rb"))
    end

    test "install replaces the files it staged and keeps the others" do
      write_file("lib/log/plain.rb", "committed")
      write_file("lib/log/interfaces/common_fields.rb", "written by hand")
      @staging.write("lib/log/plain.rb", "generated")
      @staging.write("lib/log/puma/start.rb", "new source")

      @staging.install("lib/log")

      assert_equal "generated", File.read(File.join(@root, "lib/log/plain.rb"))
      assert_equal "new source", File.read(File.join(@root, "lib/log/puma/start.rb"))
      assert_equal "written by hand", File.read(File.join(@root, "lib/log/interfaces/common_fields.rb"))
      assert_empty Dir.glob("**/*.rb", base: @staging.path("lib/log"))
    end

    test "install with prune removes files and directories that are no longer generated" do
      write_file("docs/generated/index.ts", "old")
      write_file("docs/generated/sources/removed/index.ts", "old")
      write_file("docs/other.ts", "outside")
      @staging.write("docs/generated/index.ts", "new")

      @staging.install("docs/generated", prune: true)

      assert_equal ["index.ts"], Dir.children(File.join(@root, "docs/generated"))
      assert_equal "new", File.read(File.join(@root, "docs/generated/index.ts"))
      assert_equal "outside", File.read(File.join(@root, "docs/other.ts"))
    end

    test "install with nothing staged leaves the repository alone" do
      write_file("schemas/meta/log-fields.json", "committed")

      @staging.install("schemas/meta", prune: true)

      assert_equal "committed", File.read(File.join(@root, "schemas/meta/log-fields.json"))
    end

    private

    def write_file(relative_path, content)
      path = File.join(@root, relative_path)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
    end
  end
end
