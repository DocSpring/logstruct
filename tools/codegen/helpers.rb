#!/usr/bin/env ruby
# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module LogStruct
  module Codegen
    module Helpers
      extend T::Sig

      TsType = T.type_alias { String }

      sig { params(sorbet: String).returns(TsType) }
      def ts_type(sorbet)
        case sorbet
        when "String" then "string"
        when "Integer" then "number"
        when "Float" then "number"
        when "Time" then "string"
        when "T::Boolean" then "boolean"
        when "T::Hash[Symbol, T.untyped]" then "Record<string, unknown>"
        when "T::Hash[String, T.untyped]" then "Record<string, unknown>"
        when "T::Array[String]" then "string[]"
        when "T::Array[Integer]" then "number[]"
        when "T::Array[Float]" then "number[]"
        when "T::Array[T::Boolean]" then "boolean[]"
        when "T::Array[T.untyped]" then "unknown[]"
        when "T.any(Integer, String)" then "number | string"
        when "T.class_of(StandardError)" then "string"
        else "any"
        end
      end

      sig { params(ts_type: String).returns(String) }
      def ts_default_for(ts_type)
        case ts_type
        when "string" then "'sample'"
        when "number" then "gen.randomFloat(0, 100)"
        when "boolean" then "true"
        when "string[]", "number[]", "boolean[]", "unknown[]" then "[]"
        when "Record<string, unknown>" then "{}"
        else "undefined as any"
        end
      end

      sig { params(str: String).returns(String) }
      def pascal_case(str)
        str.split("_").map { |s| s[0] ? T.must(s[0]).upcase + T.must(s[1..]) : s }.join
      end

      sig { params(ser: String).returns(String) }
      def source_display_name(ser)
        # Centralized overrides for display names in TS enums
        overrides = {
          "carrierwave" => "CarrierWave",
          "type_checking" => "TypeChecking",
          "logstruct" => "Internal"
        }
        overrides[ser] || pascal_case(ser)
      end

      sig { params(ser: String).returns(String) }
      def event_display_name(ser)
        overrides = {
          "ip_spoof" => "IPSpoof",
          "csrf_violation" => "CSRFViolation"
        }
        overrides[ser] || pascal_case(ser)
      end
    end
  end
end
