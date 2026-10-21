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

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "log_struct/enums"
require_relative "../tools/codegen/sorbet_generator"
require_relative "../tools/codegen/ts_generator"
require_relative "../tools/codegen/log_fields_generator"

module Scripts
  extend T::Sig

  sig { void }
  def self.run
    root = T.let(File.expand_path("..", __dir__), String)

    puts "Generating Sorbet Ruby structs..."
    LogStruct::Codegen::SorbetGenerator.generate_all(root)

    puts "Formatting generated Ruby code..."
    Tempfile.create("logstruct-codegen-rubocop") do |output|
      unless system("bundle", "exec", "rubocop", "-A", "lib/log_struct/log", out: output, err: [:child, :out])
        output.rewind
        warn(output.read)
        raise "Failed to format generated Ruby log structs"
      end
    end

    puts "Generating log fields JSON..."
    LogStruct::Codegen::LogFieldsGenerator.generate(root)

    puts "Generating TypeScript artifacts..."
    LogStruct::Codegen::TSGenerator.generate_all(root)

    puts "Exporting Sorbet JSON..."
    require "sorbet/typescript"

    # Ensure the freshly generated Sorbet structs are loaded before exporting
    require "log_struct/log"

    output_dir = File.join(root, "docs", "generated", "logstruct")

    exporter = Sorbet::Typescript::Exporter.new(
      enum_namespaces: ["LogStruct"],
      struct_namespaces: ["LogStruct::Log"]
    )

    exporter.export(
      enums_json: File.join(output_dir, "sorbet-enums.json"),
      structs_json: File.join(output_dir, "sorbet-log-structs.json")
    )
  end
end

Scripts.run
