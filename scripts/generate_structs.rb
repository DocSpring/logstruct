#!/usr/bin/env ruby
# typed: strict
# frozen_string_literal: true

# Ensure RubyGems and Bundler are set up so gem requires work in CI
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)
require "rubygems"
require "bundler/setup"

require "sorbet-runtime"
require "fileutils"
require "tempfile"
require "tmpdir"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "log_struct/enums"
require_relative "../tools/codegen/staging"
require_relative "../tools/codegen/sorbet_generator"
require_relative "../tools/codegen/ts_generator"
require_relative "../tools/codegen/log_fields_generator"

module Scripts
  extend T::Sig

  sig { void }
  def self.run
    root = T.let(File.expand_path("..", __dir__), String)
    # In the repository, so each generated file moves into place with a rename
    staging_parent = File.join(root, "tmp")
    FileUtils.mkdir_p(staging_parent)
    Dir.mktmpdir("codegen-", staging_parent) do |dir|
      generate(root, LogStruct::Codegen::Staging.new(root, dir))
    end
  end

  sig { params(root: String, staging: LogStruct::Codegen::Staging).void }
  def self.generate(root, staging)
    puts "Generating Sorbet Ruby structs..."
    ruby_files = LogStruct::Codegen::SorbetGenerator.generate_all(root, staging)

    puts "Formatting generated Ruby code..."
    format_ruby(root, staging, ruby_files)
    # The JSON export loads these structs
    staging.install(LogStruct::Codegen::SorbetGenerator::OUT_DIR)

    puts "Generating log fields JSON..."
    LogStruct::Codegen::LogFieldsGenerator.generate(staging)
    staging.install(File.dirname(LogStruct::Codegen::LogFieldsGenerator::OUT_FILE))

    puts "Generating TypeScript artifacts..."
    LogStruct::Codegen::TSGenerator.generate_all(root, staging)

    puts "Exporting Sorbet JSON..."
    require "sorbet/typescript"
    require "log_struct/log"

    output_dir = LogStruct::Codegen::TSGenerator::OUT_DIR

    exporter = Sorbet::Typescript::Exporter.new(
      enum_namespaces: ["LogStruct"],
      struct_namespaces: ["LogStruct::Log"]
    )

    exporter.export(
      enums_json: staging.path(File.join(output_dir, "sorbet-enums.json")),
      structs_json: staging.path(File.join(output_dir, "sorbet-log-structs.json"))
    )
    staging.install(output_dir, prune: true)
  end

  # RuboCop's config names files by their paths relative to it (plain.rb may have an untyped prop), so a copy at
  # the staging root applies to each staged file as it does to the file it replaces
  sig { params(root: String, staging: LogStruct::Codegen::Staging, files: T::Array[String]).void }
  def self.format_ruby(root, staging, files)
    FileUtils.cp(File.join(root, ".rubocop.yml"), staging.path(".rubocop.yml"))
    Tempfile.create("logstruct-codegen-rubocop") do |output|
      # The files are named, because RuboCop leaves out what's under tmp/ when it searches a directory. Sorbet
      # can't check a splat of an Array whose size it doesn't know.
      command = ["bundle", "exec", "rubocop", "-A", *files]
      unless system(*T.unsafe(command), chdir: staging.dir, out: output, err: [:child, :out])
        output.rewind
        warn(output.read)
        raise "Failed to format generated Ruby log structs"
      end
    end
  end
end

Scripts.run
