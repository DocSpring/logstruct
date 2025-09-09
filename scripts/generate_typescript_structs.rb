#!/usr/bin/env ruby
# typed: strict
# frozen_string_literal: true

require "yaml"
require "fileutils"
require "sorbet-runtime"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "log_struct"

ROOT = T.let(File.expand_path("..", __dir__), String)
SCHEMAS_DIR = T.let(File.join(ROOT, "schemas", "log_sources"), String)
OUT_DIR = T.let(File.join(ROOT, "site", "generated", "logstruct"), String)

# Reuse schema loader from generate_log_structs.rb
require_relative "generate_log_structs"

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
    generate_shared

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

  sig { void }
  def self.generate_shared
    out = File.join(OUT_DIR, "shared.ts")
    lines = []
    lines << "import { LogField, Event, Source, Level } from './enums'"
    lines << "export type AdditionalData = Record<string, unknown>"
    lines << "export function isoNow(): string { return new Date().toISOString() }"
    lines << ""
    lines << "export interface RandomGen {"
    lines << "  randomInt(min: number, max: number): number"
    lines << "  randomFloat(min: number, max: number, decimals?: number): number"
    lines << "  randomHex(length: number): string"
    lines << "  sample<T>(arr: T[]): T"
    lines << "}"
    lines << ""
    lines << "export const SampleHelpers = {"
    lines << "  duration: (gen: RandomGen) => gen.randomFloat(1, 2000),"
    lines << "  hex8: (gen: RandomGen) => gen.randomHex(8),"
    lines << "  httpMethod: (gen: RandomGen) => gen.sample(['GET','POST','PUT','DELETE']),"
    lines << "  path: (gen: RandomGen) => `/api/${gen.randomInt(1, 100)}`,"
    lines << "  status: (gen: RandomGen) => gen.randomInt(200, 599),"
    lines << "  queue: (gen: RandomGen) => gen.sample(['default','mailers','critical','low']),"
    lines << "  email: (gen: RandomGen) => `user${gen.randomInt(1,999)}@example.com`,"
    lines << "  emailArray: (gen: RandomGen) => [(`user${gen.randomInt(1,999)}@example.com`)],"
    lines << "  filename: (gen: RandomGen) => gen.sample(['file.txt','image.png','data.json']),"
    lines << "  mime: (gen: RandomGen) => gen.sample(['text/plain','image/png','application/json']),"
    lines << "  url: (_gen: RandomGen) => 'https://example.com/file',"
    lines << "  ip: (gen: RandomGen) => gen.sample(['127.0.0.1','10.0.0.1','192.168.1.1']),"
    lines << "  threadId: (gen: RandomGen) => `thread-${gen.randomHex(4)}`,"
    lines << "  processId: (gen: RandomGen) => gen.randomInt(1000, 99999),"
    lines << "  errClass: (gen: RandomGen) => gen.sample(['RuntimeError','ArgumentError','TimeoutError']),"
    lines << "  name: (gen: RandomGen) => gen.sample(['User Load','Project Load','Order Load']),"
    lines << "  sql: (_gen: RandomGen) => 'SELECT 1',"
    lines << "} as const"
    lines << ""
    lines << "export const SampleByLogField: Readonly<Record<LogField, (gen: RandomGen) => any>> = {"
    lines << "  [LogField.Path]: SampleHelpers.path,"
    lines << "  [LogField.Range]: (_gen: RandomGen) => '0-100',"
    lines << '  [LogField.Backtrace]: (_gen: RandomGen) => ["app/models/user.rb:1:in find", "app/controllers/home_controller.rb:10:in show"],'
    lines << "  [LogField.Location]: (_gen: RandomGen) => 'store/file.txt',"
    lines << "  [LogField.Storage]: (_gen: RandomGen) => 'store',"
    lines << "  [LogField.Timestamp]: (_gen: RandomGen) => new Date().toISOString(),"
    lines << "  [LogField.Source]: (_gen: RandomGen) => 'app',"
    lines << "  [LogField.Message]: (_gen: RandomGen) => 'Example message',"
    lines << "  [LogField.HttpMethod]: SampleHelpers.httpMethod,"
    lines << "  [LogField.SourceIp]: SampleHelpers.ip,"
    lines << "  [LogField.UserAgent]: (_gen: RandomGen) => 'Mozilla/5.0',"
    lines << "  [LogField.Referer]: (_gen: RandomGen) => 'https://example.com',"
    lines << "  [LogField.RequestId]: SampleHelpers.hex8,"
    lines << "  [LogField.Controller]: (_gen: RandomGen) => 'HomeController',"
    lines << "  [LogField.Action]: (_gen: RandomGen) => 'index',"
    lines << "  [LogField.View]: (gen: RandomGen) => gen.randomFloat(0, 200),"
    lines << "  [LogField.Params]: (_gen: RandomGen) => ({}),"
    lines << "  [LogField.BlockedHosts]: (_gen: RandomGen) => ['malicious.example.com'],"
    lines << "  [LogField.ClientIp]: SampleHelpers.ip,"
    lines << "  [LogField.XForwardedFor]: (_gen: RandomGen) => '203.0.113.1, 70.41.3.18',"
    lines << "  [LogField.To]: SampleHelpers.emailArray,"
    lines << "  [LogField.From]: SampleHelpers.email,"
    lines << "  [LogField.Subject]: (_gen: RandomGen) => 'Hello',"
    lines << "  [LogField.ErrClass]: SampleHelpers.errClass,"
    lines << "  [LogField.JobId]: SampleHelpers.hex8,"
    lines << "  [LogField.JobClass]: (_gen: RandomGen) => 'HardJob',"
    lines << "  [LogField.QueueName]: SampleHelpers.queue,"
    lines << "  [LogField.Arguments]: (_gen: RandomGen) => [1],"
    lines << "  [LogField.RetryCount]: (gen: RandomGen) => gen.randomInt(0, 5),"
    lines << "  [LogField.Retries]: (gen: RandomGen) => gen.randomInt(0, 5),"
    lines << "  [LogField.Attempt]: (gen: RandomGen) => gen.randomInt(1, 3),"
    lines << "  [LogField.Executions]: (gen: RandomGen) => gen.randomInt(0, 5),"
    lines << "  [LogField.ExceptionExecutions]: (gen: RandomGen) => gen.randomInt(0, 3),"
    lines << "  [LogField.ProviderJobId]: SampleHelpers.hex8,"
    lines << "  [LogField.ScheduledAt]: (_gen: RandomGen) => new Date().toISOString(),"
    lines << "  [LogField.StartedAt]: (_gen: RandomGen) => new Date().toISOString(),"
    lines << "  [LogField.FinishedAt]: (_gen: RandomGen) => new Date().toISOString(),"
    lines << "  [LogField.DurationMs]: SampleHelpers.duration,"
    lines << "  [LogField.WaitMs]: SampleHelpers.duration,"
    lines << "  [LogField.ExecutionTime]: SampleHelpers.duration,"
    lines << "  [LogField.WaitTime]: SampleHelpers.duration,"
    lines << "  [LogField.RunTime]: SampleHelpers.duration,"
    lines << "  [LogField.Level]: (_gen: RandomGen) => 'info',"
    lines << "  [LogField.Event]: (_gen: RandomGen) => 'log',"
    lines << "  [LogField.CronKey]: (_gen: RandomGen) => 'daily',"
    lines << "  [LogField.Priority]: (gen: RandomGen) => gen.randomInt(0, 100),"
    lines << "  [LogField.Vars]: (_gen: RandomGen) => ['API_KEY'],"
    lines << "  [LogField.ErrorMessage]: (_gen: RandomGen) => 'Something failed',"
    lines << "  [LogField.ProcessId]: SampleHelpers.processId,"
    lines << "  [LogField.Snapshot]: (_gen: RandomGen) => true,"
    lines << "  [LogField.Context]: (_gen: RandomGen) => ({ ctx: 'demo' }),"
    lines << "  [LogField.ThreadId]: SampleHelpers.threadId,"
    lines << "  [LogField.Prefix]: (_gen: RandomGen) => 'logstruct',"
    lines << "  [LogField.Checksum]: SampleHelpers.hex8,"
    lines << "  [LogField.FileId]: SampleHelpers.hex8,"
    lines << "  [LogField.Operation]: (_gen: RandomGen) => 'upload',"
    lines << "  [LogField.File]: (_gen: RandomGen) => 'file.txt',"
    lines << "  [LogField.UploadOptions]: (_gen: RandomGen) => ({ acl: 'public' }),"
    lines << "  [LogField.MimeType]: SampleHelpers.mime,"
    lines << "  [LogField.Uploader]: (_gen: RandomGen) => 'AvatarUploader',"
    lines << "  [LogField.Model]: (_gen: RandomGen) => 'User',"
    lines << "  [LogField.MountPoint]: (_gen: RandomGen) => 'avatar',"
    lines << "  [LogField.Sql]: SampleHelpers.sql,"
    lines << "  [LogField.Name]: SampleHelpers.name,"
    lines << "  [LogField.RowCount]: (gen: RandomGen) => gen.randomInt(0, 100),"
    lines << "  [LogField.BindParams]: (_gen: RandomGen) => [1],"
    lines << "  [LogField.DatabaseName]: (_gen: RandomGen) => 'production',"
    lines << "  [LogField.ConnectionPoolSize]: (gen: RandomGen) => gen.randomInt(1, 20),"
    lines << "  [LogField.ActiveConnections]: (gen: RandomGen) => gen.randomInt(1, 20),"
    lines << "  [LogField.OperationType]: (_gen: RandomGen) => 'SELECT',"
    lines << "  [LogField.TableNames]: (_gen: RandomGen) => ['users'],"
    lines << "  [LogField.Serializer]: (_gen: RandomGen) => 'UserSerializer',"
    lines << "  [LogField.Adapter]: (_gen: RandomGen) => 'attributes',"
    lines << "  [LogField.ResourceClass]: (_gen: RandomGen) => 'User',"
    lines << "  [LogField.AhoyEvent]: (_gen: RandomGen) => 'signup',"
    lines << "  [LogField.Filename]: SampleHelpers.filename,"
    lines << "  [LogField.Properties]: (_gen: RandomGen) => ({ plan: 'pro' }),"
    lines << "  [LogField.Data]: (_gen: RandomGen) => ({}),"
    lines << "  [LogField.DownloadOptions]: (_gen: RandomGen) => ({ filename: 'file.txt' }),"
    lines << "  [LogField.Size]: (gen: RandomGen) => gen.randomInt(1000, 1000000),"
    lines << "  [LogField.Options]: (_gen: RandomGen) => ({}),"
    lines << "  [LogField.Metadata]: (_gen: RandomGen) => ({ width: 100, height: 100 }),"
    lines << "  [LogField.Exist]: (_gen: RandomGen) => true,"
    lines << "  [LogField.Url]: SampleHelpers.url,"
    lines << "  [LogField.Status]: SampleHelpers.status,"
    lines << "  [LogField.Database]: (_gen: RandomGen) => 'primary',"
    lines << "  [LogField.BlockedHost]: (_gen: RandomGen) => 'malicious.example.com',"
    lines << "  [LogField.Format]: (_gen: RandomGen) => 'html',"
    lines << "} as const"
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
      lines << "import { AdditionalData, isoNow, RandomGen, SampleByLogField, SampleHelpers } from '../../shared'"
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
    lines << "export * from './shared'"
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
