#!/usr/bin/env ruby
# typed: strict
# frozen_string_literal: true

require "json"
require "sorbet-runtime"
begin
  require "log_struct/enums/log_field"
rescue LoadError
  require_relative "../../lib/log_struct/enums/log_field"
end
require_relative "staging"

module LogStruct
  module Codegen
    module LogFieldsGenerator
      extend T::Sig

      OUT_FILE = "schemas/meta/log-fields.json"

      sig { params(staging: Staging).void }
      def self.generate(staging)
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

        staging.write(OUT_FILE, JSON.pretty_generate(data) + "\n")
        puts "Generated: #{OUT_FILE} (#{names.size} fields)"
      end

      sig { returns(T::Array[String]) }
      def self.enum_constant_names
        klass = LogStruct::LogField
        # rubocop:disable Sorbet/ConstantsFromStrings
        klass.values.filter_map do |val|
          const_name = klass.constants.find { |cn| klass.const_get(cn) == val }&.to_s
          const_name
        end.sort
        # rubocop:enable Sorbet/ConstantsFromStrings
      end
    end
  end
end
