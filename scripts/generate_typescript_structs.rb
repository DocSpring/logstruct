#!/usr/bin/env ruby
# typed: strict
# frozen_string_literal: true

# Ensure RubyGems and Bundler are set up so gem requires work in CI
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)
require "rubygems"
require "bundler/setup"

require "yaml"
require "fileutils"
require "sorbet-runtime"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "log_struct"

ROOT = T.let(File.expand_path("..", __dir__), String)
SCHEMAS_DIR = T.let(File.join(ROOT, "schemas", "log_sources"), String)
OUT_DIR = T.let(File.join(ROOT, "site", "generated", "logstruct"), String)

# Reuse schema loader helpers from Sorbet generator
require_relative "generate_sorbet_log_structs"

module TSGen
  extend T::Sig

  sig { params(sorbet: String).returns(String) }
  def self.ts_type(sorbet)
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

  sig { params(name: String).returns(String) }
  def self.snake(name)
    name.gsub(/([A-Z]+)([A-Z][a-z])/, '\\1_\\2')
      .gsub(/([a-z\\d])([A-Z])/, '\\1_\\2')
      .downcase
  end

  sig { void }
  def self.generate
    FileUtils.rm_rf(OUT_DIR)
    FileUtils.mkdir_p(OUT_DIR)

    generate_enums

    schemas = Dir[File.join(SCHEMAS_DIR, "*.{yml,yaml}")].sort
    schemas.each do |path|
      raw = YAML.safe_load_file(path)
      schema = symbolize_keys(raw)
      payload = build_source_payload(schema)
      generate_source_ts(payload)
    end

    generate_barrel
  end

  sig { void }
  def self.generate_enums
    out = File.join(OUT_DIR, "enums.ts")
    lines = []
    lines << "/* eslint-disable @typescript-eslint/no-explicit-any */"
    lines << "// Auto-generated from YAML schemas"
    lines << ""
    # LogField maps to compact keys
    lines << "export enum LogField {"
    # rubocop:disable Sorbet/ConstantsFromStrings
    LogStruct::LogField.constants.each do |cn|
      val = LogStruct::LogField.const_get(cn)
      next unless val.is_a?(LogStruct::LogField)
      lines << "  #{cn} = \"#{val.serialize}\","
    end
    # rubocop:enable Sorbet/ConstantsFromStrings
    lines << "}"
    lines << ""
    # Source
    lines << "export enum Source {"
    LogStruct::Source.values.each do |v|
      ser = v.serialize.to_s
      name = case ser
      when "carrierwave" then "CarrierWave"
      when "type_checking" then "TypeChecking"
      when "logstruct" then "Internal"
      else ser.split("_").map { |s| s[0] ? T.must(s[0]).upcase + T.must(s[1..]) : s }.join
      end
      lines << "  #{name} = \"#{ser}\","
    end
    lines << "}"
    lines << ""
    # Level
    lines << "export enum Level {"
    LogStruct::Level.values.each do |v|
      ser = v.serialize.to_s
      name = ser.split("_").map { |s| s[0] ? T.must(s[0]).upcase + T.must(s[1..]) : s }.join
      lines << "  #{name} = \"#{ser}\","
    end
    lines << "}"
    lines << ""
    # Event
    lines << "export enum Event {"
    LogStruct::Event.values.each do |v|
      ser = v.serialize.to_s
      name = case ser
      when "ip_spoof" then "IPSpoof"
      when "csrf_violation" then "CSRFViolation"
      else ser.split("_").map { |s| s[0] ? T.must(s[0]).upcase + T.must(s[1..]) : s }.join
      end
      lines << "  #{name} = \"#{ser}\","
    end
    lines << "}"

    File.write(out, lines.join("\n") + "\n")
  end

  sig { params(payload: SourcePayload).void }
  def self.generate_source_ts(payload)
    src_snake = payload.source_snake
    dir = File.join(OUT_DIR, "sources", src_snake)
    FileUtils.mkdir_p(dir)

    payload.events.each do |evt|
      ts_source_const = T.let(payload.source_enum.gsub("::", "."), String)
      event_only = evt.fields.reject { |ef| payload.base_fields.any? { |cf| cf.enum_name == ef.enum_name } }
      out = File.join(dir, "#{snake(evt.name)}.ts")
      lines = []
      lines << "import { Event, Level, LogField, Source } from '../../enums'"
      lines << "import { AdditionalData, isoNow, RandomGen, SampleByLogField, SampleHelpers } from '../../../lib/log_generation/sample-data'"
      lines << ""
      # Constructor interface
      lines << "export interface #{payload.source_name}#{evt.name}Ctor {"
      lines << "  timestamp?: string"
      lines << "  level?: Level"
      lines << "  additional_data?: AdditionalData"
      if ts_source_const == "Source"
        lines << "  source: Source"
      end
      (payload.base_fields + event_only).each do |f|
        ts = ts_type(f.sorbet_type)
        optional = f.required ? "" : "?"
        lines << "  #{f.prop_name}#{optional}: #{ts}"
      end
      lines << "}"
      lines << ""
      # Class
      class_name = "#{payload.source_name}#{evt.name}"
      lines << "export class #{class_name} {"
      ts_source_const = payload.source_enum.gsub("::", ".")
      lines << if ts_source_const != "Source"
        "  readonly source = #{ts_source_const}"
      else
        "  readonly source: Source"
      end
      lines << "  readonly event = Event.#{evt.name}"
      lines << "  readonly timestamp: string"
      lines << "  readonly level: Level"
      lines << "  readonly additional_data?: AdditionalData"
      (payload.base_fields + event_only).each do |f|
        ts = ts_type(f.sorbet_type)
        optional = f.required ? "" : "?"
        lines << "  readonly #{f.prop_name}#{optional}: #{ts}"
      end
      lines << ""
      lines << "  constructor(args: #{class_name}Ctor) {"
      lines << "    this.timestamp = args.timestamp ?? isoNow()"
      lines << "    this.level = args.level ?? Level.Info"
      if ts_source_const == "Source"
        lines << "    this.source = args.source"
      end
      lines << "    this.additional_data = args.additional_data"
      (payload.base_fields + event_only).each do |f|
        lines << "    this.#{f.prop_name} = args.#{f.prop_name}"
      end
      lines << "  }"
      lines << ""
      lines << "  serialize(): Record<string, unknown> {"
      lines << "    const h: Record<string, unknown> = {}"
      lines << "    h[LogField.Source] = this.source"
      lines << "    h[LogField.Event] = this.event"
      lines << "    h[LogField.Timestamp] = this.timestamp"
      lines << "    h[LogField.Level] = this.level"
      payload.base_fields.each do |f|
        lines << if f.required
          "    if (this.#{f.prop_name} !== undefined && this.#{f.prop_name} !== null) h[LogField.#{f.enum_name}] = this.#{f.prop_name}"
        else
          "    if (this.#{f.prop_name} !== undefined) h[LogField.#{f.enum_name}] = this.#{f.prop_name}"
        end
      end
      event_only.each do |f|
        lines << if f.required
          "    h[LogField.#{f.enum_name}] = this.#{f.prop_name}"
        else
          "    if (this.#{f.prop_name} !== undefined) h[LogField.#{f.enum_name}] = this.#{f.prop_name}"
        end
      end
      lines << "    if (this.additional_data) Object.assign(h, this.additional_data)"
      lines << "    return h"
      lines << "  }"
      lines << ""
      # Static random factory (basic fallback sampling)
      ctor_interface = "#{payload.source_name}#{evt.name}Ctor"
      lines << "  static random(gen: RandomGen, overrides: Partial<#{ctor_interface}> = {}): #{class_name} {"
      lines << "    const args: #{ctor_interface} = {"
      # For generic source, pick a random Source; for fixed, do nothing (readonly)
      if ts_source_const == "Source"
        lines << "      source: (gen.sample(Object.values(Source) as unknown as Source[])),"
      end
      # Populate defaults for all fields with precedence:
      # schema sample_type > SampleByLogField > base type fallback
      (payload.base_fields + event_only).each do |f|
        ts = ts_type(f.sorbet_type)
        base = case ts
        when "string" then "'sample'"
        when "number" then "gen.randomFloat(0, 100)"
        when "boolean" then "true"
        when "string[]" then "[]"
        when "number[]" then "[]"
        when "boolean[]" then "[]"
        when "unknown[]" then "[]"
        when "Record<string, unknown>" then "{}"
        else "undefined as any"
        end
        lines << if f.sample_type
          "      #{f.prop_name}: (SampleHelpers as any)['#{f.sample_type}']?.(gen) ?? #{base},"
        else
          "      #{f.prop_name}: (SampleByLogField as any)[LogField.#{f.enum_name}]?.(gen) ?? #{base},"
        end
      end
      lines << "      ...overrides,"
      lines << "    }"
      lines << "    return new #{class_name}(args)"
      lines << "  }"
      lines << "}"

      File.write(out, lines.join("\n") + "\n")
    end

    # Barrel
    barrel = []
    type_lines = []
    # Import types explicitly for union
    payload.events.each do |evt|
      class_name = "#{payload.source_name}#{evt.name}"
      file_name = snake(evt.name)
      barrel << "export * from './#{file_name}'"
      type_lines << class_name
    end
    barrel << ""
    # Import types (type-only) so the union can reference them
    payload.events.each do |evt|
      class_name = "#{payload.source_name}#{evt.name}"
      file_name = snake(evt.name)
      barrel.unshift("import type { #{class_name} } from './#{file_name}'")
    end
    union_name = "#{payload.source_name}Events"
    union_body = type_lines.map { |n| "  | #{n}" }.join("\n")
    barrel << "export type #{union_name} =" \
               "\n#{union_body}"
    File.write(File.join(dir, "index.ts"), barrel.join("\n") + "\n")
  end

  sig { void }
  def self.generate_barrel
    roots = Dir[File.join(OUT_DIR, "sources", "*")].map { |p| File.basename(p) }
    lines = []
    lines << "export * from './enums'"
    lines << "export * from '../../lib/log_generation/sample-data'"
    roots.each do |sn|
      lines << "export * as #{sn.split("_").map(&:capitalize).join} from './sources/#{sn}'"
    end
    # Provide LogType enum (top-level sources) + AllLogTypes array for UI iteration
    lines << ""
    lines << "export enum LogType {"
    roots.each do |sn|
      name = sn.split("_").map(&:capitalize).join
      lines << "  #{name.upcase} = \"#{name}\","
    end
    lines << "}"
    lines << ""
    lines << "export const AllLogTypes: Array<LogType> = ["
    roots.each do |sn|
      name = sn.split("_").map(&:capitalize).join
      lines << "  LogType.#{name.upcase},"
    end
    lines << "]"
    File.write(File.join(OUT_DIR, "index.ts"), lines.join("\n") + "\n")
  end
end

TSGen.generate

# Also export Sorbet JSON artifacts for docs display
begin
  require_relative "../tools/log_types_exporter"
  exporter = LogStruct::Tools::LogTypesExporter.new(File.join(OUT_DIR, "log-types.ts"))
  enums = exporter.export_enums
  logs = exporter.export_log_structs
  exporter.export_enums_to_json(enums, File.join(OUT_DIR, "sorbet-enums.json"))
  exporter.export_log_structs_to_json(logs, File.join(OUT_DIR, "sorbet-log-structs.json"))
rescue => e
  warn("Warning exporting Sorbet JSON: #{e}")
end
