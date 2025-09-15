#!/usr/bin/env ruby
# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module LogStruct
  module Codegen
    extend T::Sig

    class FieldSpec < T::Struct
      const :enum_name, String # e.g., "RequestId"
      const :prop_name, String # e.g., "request_id"
      const :type, String
      const :sorbet_type, String
      const :required, T::Boolean
      const :sample_type, T.nilable(String)
    end

    class EventSpec < T::Struct
      const :name, String
      const :fields, T::Array[FieldSpec]
    end

    class SourcePayload < T::Struct
      const :source_name, String
      const :source_snake, String
      const :source_enum, String
      const :source_has_default, T::Boolean
      const :base_fields, T::Array[FieldSpec]
      const :events, T::Array[EventSpec]
      const :additional_data, T::Boolean
      const :add_request_fields, T::Boolean
    end

    sig { params(str: String).returns(String) }
    def self.snake_case(str)
      str
        .gsub(/([A-Z]+)([A-Z][a-z])/, '\\1_\\2')
        .gsub(/([a-z\\d])([A-Z])/, '\\1_\\2')
        .tr("-", "_")
        .downcase
    end

    sig { params(str: String).returns(String) }
    def self.camelize(str)
      str.split("_").map { |s| s[0] ? T.must(s[0]).upcase + T.must(s[1..]) : s }.join
    end

    sig { params(obj: T.untyped).returns(T.untyped) }
    def self.symbolize_keys(obj)
      case obj
      when Hash
        obj.each_with_object({}) { |(k, v), h| h[k.to_sym] = symbolize_keys(v) }
      when Array
        obj.map { |v| symbolize_keys(v) }
      else
        obj
      end
    end

    sig { params(type_str: String).returns(String) }
    def self.type_to_sorbet(type_str)
      # Types are already Sorbet type strings in YAML
      type_str
    end
  end
end
