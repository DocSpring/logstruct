#!/usr/bin/env ruby
# typed: strict
# frozen_string_literal: true

# Ensure RubyGems and Bundler are set up so gem requires work in CI
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)
require "rubygems"
require "bundler/setup"

require "sorbet-runtime"
require "fileutils"

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
    system("bundle exec rubocop -A lib/log_struct/log > /dev/null 2>&1")

    puts "Generating log fields JSON..."
    LogStruct::Codegen::LogFieldsGenerator.generate(root)

    puts "Generating TypeScript artifacts..."
    LogStruct::Codegen::TSGenerator.generate_all(root)

    puts "Exporting Sorbet JSON..."
    begin
      require_relative "../tools/log_types_exporter"
      exporter = LogStruct::Tools::LogTypesExporter.new(File.join(root, "site", "generated", "logstruct", "log-types.ts"))
      enums = exporter.export_enums
      logs = exporter.export_log_structs
      exporter.export_enums_to_json(enums, File.join(root, "site", "generated", "logstruct", "sorbet-enums.json"))
      exporter.export_log_structs_to_json(logs, File.join(root, "site", "generated", "logstruct", "sorbet-log-structs.json"))
    rescue => e
      warn("Warning exporting Sorbet JSON: #{e}")
    end
  end
end

Scripts.run
