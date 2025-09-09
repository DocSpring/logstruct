#!/usr/bin/env ruby
# typed: strict
# frozen_string_literal: true

# Usage: ruby scripts/generate_log_structs.rb
# Reads schemas/log_sources/*.yml and generates Ruby T::Struct variants
# under lib/log_struct/log/generated/<source_snake>.rb

require "yaml"
require "erb"
require "fileutils"
require "sorbet-runtime"

extend T::Sig # rubocop:disable Style/MixinUsage

ROOT = T.let(File.expand_path("..", __dir__), String)
SCHEMAS_DIR = T.let(File.join(ROOT, "schemas", "log_sources"), String)
OUT_BASE_DIR = T.let(File.join(ROOT, "lib", "log_struct", "log"), String)
TEMPLATES_DIR = T.let(File.join(ROOT, "scripts", "templates", "generate_log_structs"), String)

FileUtils.mkdir_p(OUT_BASE_DIR)

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
def snake_case(str)
  str
    .gsub(/([A-Z]+)([A-Z][a-z])/, '\\1_\\2')
    .gsub(/([a-z\\d])([A-Z])/, '\\1_\\2')
    .tr("-", "_")
    .downcase
end

sig { params(str: String).returns(String) }
def camelize(str)
  str.split("_").map { |s| s[0] ? T.must(s[0]).upcase + T.must(s[1..]) : s }.join
end

sig { params(obj: T.untyped).returns(T.untyped) }
def symbolize_keys(obj)
  case obj
  when Hash
    obj.each_with_object({}) { |(k, v), h| h[k.to_sym] = symbolize_keys(v) }
  when Array
    obj.map { |v| symbolize_keys(v) }
  else
    obj
  end
end

sig { returns(T::Array[T::Hash[Symbol, T.untyped]]) }
def load_schemas
  Dir[File.join(SCHEMAS_DIR, "*.{yml,yaml}")].sort.map do |path|
    data = symbolize_keys(YAML.safe_load_file(path))
    data[:__path] = path
    T.let(data, T::Hash[Symbol, T.untyped])
  end
end

sig { params(type_str: String).returns(String) }
def type_to_sorbet(type_str)
  # Types are already Sorbet type strings in YAML (e.g., String, Integer, T::Boolean, T::Array[String])
  type_str
end

sig { params(sorbet_type: String, required: T::Boolean).returns(String) }
def nilable(sorbet_type, required)
  required ? sorbet_type : "T.nilable(#{sorbet_type})"
end

sig { params(fields_hash: T.untyped, default_required: T::Boolean).returns(T::Array[FieldSpec]) }
def normalize_fields(fields_hash, default_required)
  fields = T.let([], T::Array[FieldSpec])
  (fields_hash || {}).each do |name_any, spec|
    key = name_any.to_s
    if spec.is_a?(String)
      type = spec
      required = default_required
      sample_type = nil
    else
      type = spec.fetch(:type)
      required = spec.key?(:required) ? T.cast(spec[:required], T::Boolean) : default_required
      sample_type = T.let(spec[:sample_type]&.to_s, T.nilable(String))
    end
    enum_name = /\A[A-Z]/.match?(key) ? key : camelize(key)
    prop_name = snake_case(enum_name)
    fields << FieldSpec.new(enum_name: enum_name, prop_name: prop_name, type: type, sorbet_type: type_to_sorbet(type), required: T.let(required, T::Boolean), sample_type: sample_type)
  end
  fields
end

sig { params(schema: T::Hash[Symbol, T.untyped]).returns(SourcePayload) }
def build_source_payload(schema)
  source_name = schema.fetch(:source)
  source_enum = schema.dig(:consts, :source) || "Source::#{source_name}"
  source_has_default = source_enum != "Source"

  base_fields = T.let([], T::Array[FieldSpec])
  if schema.key?(:base)
    base = T.cast(schema[:base], T::Hash[Symbol, T.untyped])
    base_default_required = if base.key?(:default_required)
      !!base[:default_required]
    else
      true
    end
    base_fields = normalize_fields(base[:fields] || {}, base_default_required)
  elsif schema.key?(:base_fields)
    base_fields = normalize_fields(schema[:base_fields], false)
  end

  additional_data = T.cast(schema[:additional_data], T.nilable(T::Boolean)) || false
  add_request_fields = T.cast(schema[:add_request_fields], T.nilable(T::Boolean)) || false

  if add_request_fields
    # Append standard request fields to base_fields so builders can accept them
    req_fields = [
      ["Path", "String"],
      ["HttpMethod", "String"],
      ["SourceIp", "String"],
      ["UserAgent", "String"],
      ["Referer", "String"],
      ["RequestId", "String"]
    ]
    req_fields.each do |name, type|
      base_fields << FieldSpec.new(enum_name: name, prop_name: snake_case(name), type: type, sorbet_type: type_to_sorbet(type), required: false)
    end
  end

  events = T.let([], T::Array[EventSpec])
  (schema[:events] || {}).each do |event_name_any, defn_any|
    event_name = event_name_any.to_s
    defn = defn_any.nil? ? {} : T.cast(defn_any, T::Hash[Symbol, T.untyped])
    # Event-only fields (base_fields handled separately)
    required_by_default = defn.key?(:default_required) ? !!defn[:default_required] : true
    fields = normalize_fields(defn[:fields] || {}, required_by_default)
    events << EventSpec.new(name: event_name, fields: fields)
  end

  SourcePayload.new(
    source_name: source_name,
    source_snake: schema[:snake_case] || snake_case(source_name),
    source_enum: source_enum,
    source_has_default: source_has_default,
    base_fields: base_fields,
    events: events,
    additional_data: additional_data,
    add_request_fields: add_request_fields
  )
end

class TemplateBinding
  extend T::Sig

  sig { params(payload: SourcePayload, event: T.nilable(EventSpec), extras: T::Hash[Symbol, T.untyped]).void }
  def initialize(payload, event, extras = {})
    @payload = payload
    @event = event
    extras.each do |k, v|
      instance_variable_set(:"@#{k}", v)
      define_singleton_method(k) { instance_variable_get(:"@#{k}") }
    end
  end

  sig { params(type: String, required: T::Boolean).returns(String) }
  def nilable(type, required)
    required ? type : "T.nilable(#{type})"
  end

  # Indent lines in the string except the first line
  sig { params(str: String, level: Integer, all: T::Boolean).returns(String) }
  def indent(str, level = 2, all: false)
    str.split("\n").map.with_index do |line, index|
      (index == 0 && !all) ? line : " " * level + line
    end.join("\n")
  end

  sig { params(ev: EventSpec).returns(T::Array[FieldSpec]) }
  def event_only(ev)
    ev.fields.reject { |ef| @payload.base_fields.any? { |cf| cf.enum_name == ef.enum_name } }
  end

  sig { params(event_only: T::Array[FieldSpec]).returns(T::Array[String]) }
  def event_types(event_only)
    req = event_only.select { |ef| ef.required }
    opt = event_only.reject { |ef| ef.required }
    (req + opt).map do |ef|
      sorbet_type = nilable(ef.sorbet_type, ef.required)
      "#{ef.prop_name}: #{sorbet_type}"
    end
  end

  sig { params(event_only: T::Array[FieldSpec]).returns(T::Array[String]) }
  def event_params(event_only)
    req = event_only.select { |ef| ef.required }
    opt = event_only.reject { |ef| ef.required }
    req.map { |ef| "#{ef.prop_name}:" } + opt.map { |ef| "#{ef.prop_name}: nil" }
  end

  sig { returns(String) }
  def base_fields_params
    @payload.base_fields.map { |f| "#{f.prop_name}:" + (f.required ? "" : " nil") }.join(",\n")
  end

  sig { params(base_fields: T::Array[FieldSpec], event_only: T::Array[FieldSpec]).returns(String) }
  def builder_method_types_from_lists(base_fields, event_only)
    types = []
    types << "base_fields: BaseFields" if base_fields.any?
    types += event_types(event_only)
    types << "timestamp: Time"
    types.join(",\n")
  end

  sig { params(base_fields: T::Array[FieldSpec], event_only: T::Array[FieldSpec]).returns(String) }
  def builder_method_params_from_lists(base_fields, event_only)
    # <% if base_fields.any? -%>base_fields:, <% end -%><%= event_params(event_only) %>
    params = []
    params << "base_fields:" if base_fields.any?
    params += event_params(event_only)
    params << "timestamp: Time.now"
    params.join(",\n")
  end

  sig { params(base_fields: T::Array[FieldSpec], event_only: T::Array[FieldSpec]).returns(String) }
  def builder_method_kwargs_from_lists(base_fields, event_only)
    ""
  end

  # Convenience helpers for templates taking an EventSpec
  sig { params(evt: EventSpec).returns(String) }
  def builder_method_types(evt)
    builder_method_types_from_lists(@payload.base_fields, event_only(evt))
  end

  sig { params(evt: EventSpec).returns(String) }
  def builder_method_params(evt)
    builder_method_params_from_lists(@payload.base_fields, event_only(evt))
  end

  sig { params(evt: EventSpec).returns(String) }
  def builder_method_kwargs(evt)
    builder_method_kwargs_from_lists(@payload.base_fields, event_only(evt))
  end

  sig { returns(Binding) }
  def get_binding
    binding
  end

  # Expose payload for template accessors
  sig { returns(String) }
  def source_name = @payload.source_name

  sig { returns(String) }
  def source_snake = @payload.source_snake

  sig { returns(String) }
  def source_enum = @payload.source_enum

  sig { returns(T::Array[FieldSpec]) }
  def base_fields = @payload.base_fields

  sig { returns(T::Array[EventSpec]) }
  def events = @payload.events

  sig { returns(EventSpec) }
  def event
    T.must(@event)
  end

  sig { returns(T::Boolean) }
  def additional_data = @payload.additional_data

  sig { returns(T::Boolean) }
  def add_request_fields = @payload.add_request_fields

  sig { returns(T::Boolean) }
  def source_has_default = @payload.source_has_default

  sig { returns(T::Hash[Symbol, T.untyped]) }
  def schema = @payload.serialize

  # Shared header for all generated files
  sig { params(template_name: String).returns(String) }
  def header(template_name)
    <<~RUBY.chomp
      # AUTO-GENERATED: DO NOT EDIT
      # Generated by scripts/generate_log_structs.rb
      # Schemas dir: schemas/log_sources/
      # Template: scripts/templates/generate_log_structs/#{template_name}
    RUBY
  end

  # Render a sibling partial with current binding
  sig { params(partial_name: String).returns(String) }
  def render_partial(partial_name)
    path = File.join(TEMPLATES_DIR, partial_name)
    erb = ERB.new(File.read(path), trim_mode: "-")
    erb.result(get_binding)
  end
end

sig { params(template_name: String, locals: T::Hash[Symbol, T.untyped]).returns(String) }
def render_template(template_name, locals)
  template_path = File.join(TEMPLATES_DIR, template_name)
  erb = ERB.new(File.read(template_path), trim_mode: "-")
  payload = T.cast(locals[:payload], SourcePayload)
  ev = locals.key?(:event) ? T.cast(locals[:event], T.nilable(EventSpec)) : nil
  extras = locals.dup
  extras.delete(:payload)
  extras.delete(:event)
  ctx = TemplateBinding.new(payload, ev, extras)
  erb.result(ctx.get_binding)
end

sig { params(schema: T::Hash[Symbol, T.untyped]).void }
def generate_source(schema)
  payload = build_source_payload(schema)
  source_snake = payload.source_snake
  source_dir = File.join(OUT_BASE_DIR, source_snake)

  if payload.events.size == 1
    evt = T.must(payload.events.first)
    single_out = File.join(OUT_BASE_DIR, "#{source_snake}.rb")
    single_content = render_template("event.rb.erb", {payload: payload, event: evt, single_event: true})
    File.write(single_out, single_content)
    puts "Generated: #{single_out}"
  else
    FileUtils.mkdir_p(source_dir)

    payload.events.each do |evt|
      ev_out = File.join(source_dir, "#{snake_case(evt.name)}.rb")
      ev_content = render_template("event.rb.erb", {payload: payload, event: evt, single_event: false})
      File.write(ev_out, ev_content)
      puts "Generated: #{ev_out}"
    end

    # Generate parent with context + builder methods
    parent_out = File.join(OUT_BASE_DIR, "#{source_snake}.rb")
    parent_content = render_template("source_parent.rb.erb", {payload: payload})
    File.write(parent_out, parent_content)
    puts "Generated: #{parent_out}"
  end
end

schemas = load_schemas
if schemas.empty?
  warn "No schemas found in #{SCHEMAS_DIR}"
  exit 1
end

schemas.each do |schema|
  generate_source(schema)
end

# Run rubocop -A on lib/log_struct/log
system("bundle exec rubocop -A lib/log_struct/log > /dev/null 2>&1")

# Also generate the LogField names JSON schema used by meta schema
system("ruby #{File.join(ROOT, "scripts", "generate_log_fields_json.rb")}")
