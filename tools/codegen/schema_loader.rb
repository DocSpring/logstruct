#!/usr/bin/env ruby
# typed: strict
# frozen_string_literal: true

require "yaml"
require "sorbet-runtime"

require_relative "models"

module LogStruct
  module Codegen
    module SchemaLoader
      extend T::Sig

      sig { params(root: String).returns(T::Array[T::Hash[Symbol, T.untyped]]) }
      def self.load_raw_schemas(root)
        schemas_dir = File.join(root, "schemas", "log_sources")
        Dir[File.join(schemas_dir, "*.{yml,yaml}")].sort.map do |path|
          data = LogStruct::Codegen.symbolize_keys(YAML.safe_load_file(path))
          data[:__path] = path
          T.let(data, T::Hash[Symbol, T.untyped])
        end
      end

      sig { params(fields_hash: T.untyped, default_required: T::Boolean).returns(T::Array[FieldSpec]) }
      def self.normalize_fields(fields_hash, default_required)
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
          enum_name = /\A[A-Z]/.match?(key) ? key : LogStruct::Codegen.camelize(key)
          prop_name = LogStruct::Codegen.snake_case(enum_name)
          fields << FieldSpec.new(enum_name: enum_name, prop_name: prop_name, type: type, sorbet_type: LogStruct::Codegen.type_to_sorbet(type), required: T.let(required, T::Boolean), sample_type: sample_type)
        end
        fields
      end

      sig { params(schema: T::Hash[Symbol, T.untyped]).returns(SourcePayload) }
      def self.build_source_payload(schema)
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
          req_fields = [
            ["Path", "String"],
            ["HttpMethod", "String"],
            ["SourceIp", "String"],
            ["UserAgent", "String"],
            ["Referer", "String"],
            ["RequestId", "String"]
          ]
          req_fields.each do |name, type|
            base_fields << FieldSpec.new(enum_name: name, prop_name: LogStruct::Codegen.snake_case(name), type: type, sorbet_type: LogStruct::Codegen.type_to_sorbet(type), required: false)
          end
        end

        events = T.let([], T::Array[EventSpec])
        (schema[:events] || {}).each do |event_name_any, defn_any|
          event_name = event_name_any.to_s
          defn = defn_any.nil? ? {} : T.cast(defn_any, T::Hash[Symbol, T.untyped])
          required_by_default = defn.key?(:default_required) ? !!defn[:default_required] : true
          fields = normalize_fields(defn[:fields] || {}, required_by_default)
          events << EventSpec.new(name: event_name, fields: fields)
        end

        SourcePayload.new(
          source_name: source_name,
          source_snake: schema[:snake_case] || LogStruct::Codegen.snake_case(source_name),
          source_enum: source_enum,
          source_has_default: source_has_default,
          base_fields: base_fields,
          events: events,
          additional_data: additional_data,
          add_request_fields: add_request_fields
        )
      end

      sig { params(root: String).returns(T::Array[SourcePayload]) }
      def self.payloads(root)
        load_raw_schemas(root).map { |schema| build_source_payload(schema) }
      end
    end
  end
end
