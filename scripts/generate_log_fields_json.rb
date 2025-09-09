#!/usr/bin/env ruby

# typed: strict
# frozen_string_literal: true

require "json"
require "sorbet-runtime"

ROOT = T.let(File.expand_path("..", __dir__), String)
ENUM_FILE = T.let(File.join(ROOT, "lib", "log_struct", "enums", "log_field.rb"), String)
OUT_FILE = T.let(File.join(ROOT, "schemas", "meta", "log-fields.json"), String)

require ENUM_FILE

module Generator
  extend T::Sig

  sig { returns(T::Array[String]) }
  def self.enum_constant_names
    klass = LogStruct::LogField
    klass.values.filter_map do |val|
      const_name = klass.constants.find { |cn| klass.const_get(cn) == val }&.to_s
      const_name
    end.sort
  end

  sig { returns(NilClass) }
  def self.run
    names = enum_constant_names
    data = {
      "$schema" => "http://json-schema.org/draft-07/schema#",
      "title" => "LogField Names",
      "description" => "Auto-generated enum of LogField names (human-readable) used in schemas.",
      "definitions" => {
        "LogFieldName" => {
          "type" => "string",
          "enum" => names
        }
      }
    }

    File.write(OUT_FILE, JSON.pretty_generate(data))
    puts "Generated: #{OUT_FILE} (#{names.size} fields)"
  end
end

Generator.run
