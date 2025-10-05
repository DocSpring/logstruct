#!/usr/bin/env ruby
# typed: strict
# frozen_string_literal: true

require "erb"
require "sorbet-runtime"

require_relative "models"
require_relative "helpers"

module LogStruct
  module Codegen
    class TemplateBinding
      extend T::Sig

      sig { params(payload: SourcePayload, event: T.nilable(EventSpec), root: String, extras: T::Hash[Symbol, T.untyped]).void }
      def initialize(payload, event, root, extras = {})
        @payload = payload
        @event = event
        @root = root
        extras.each do |k, v|
          instance_variable_set(:"@#{k}", v)
          define_singleton_method(k) { instance_variable_get(:"@#{k}") }
        end
      end

      sig { params(type: String, required: T::Boolean).returns(String) }
      def nilable(type, required)
        required ? type : "T.nilable(#{type})"
      end

      sig { params(str: String, level: Integer, all: T::Boolean).returns(String) }
      def indent(str, level = 2, all: false)
        str.split("\n").map.with_index { |line, index| (index == 0 && !all) ? line : " " * level + line }.join("\n")
      end

      sig { params(str: String).returns(String) }
      def snake_case(str)
        LogStruct::Codegen.snake_case(str)
      end

      sig { params(str: String).returns(String) }
      def camelize(str)
        LogStruct::Codegen.camelize(str)
      end

      include LogStruct::Codegen::Helpers

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
        @payload.base_fields.map { |f| "#{f.prop_name}: #{f.prop_name}" }.join(",\n")
      end

      sig { params(base_fields: T::Array[FieldSpec], event_only: T::Array[FieldSpec]).returns(String) }
      def builder_method_types_from_lists(base_fields, event_only)
        # Required keyword args must come before optional ones to satisfy RuboCop and Ruby semantics.
        base_req = base_fields.select { |f| f.required }
        base_opt = base_fields.reject { |f| f.required }
        ev_req = event_only.select { |f| f.required }
        ev_opt = event_only.reject { |f| f.required }

        order = []
        order += ev_req
        order += base_req
        order += base_opt
        order += ev_opt

        types = order.map { |f| "#{f.prop_name}: T.untyped" }
        types << "additional_data: T.untyped"
        types << "timestamp: T.untyped"
        types.join(",\n")
      end

      sig { params(base_fields: T::Array[FieldSpec], event_only: T::Array[FieldSpec]).returns(String) }
      def builder_method_params_from_lists(base_fields, event_only)
        base_req = base_fields.select { |f| f.required }
        base_opt = base_fields.reject { |f| f.required }
        ev_req = event_only.select { |f| f.required }
        ev_opt = event_only.reject { |f| f.required }

        params = []
        # Required first
        params += ev_req.map { |f| "#{f.prop_name}:" }
        params += base_req.map { |f| "#{f.prop_name}:" }
        # Optional next
        params += base_opt.map { |f| "#{f.prop_name}: nil" }
        params += ev_opt.map { |f| "#{f.prop_name}: nil" }
        params << "additional_data: nil"
        params << "timestamp: Time.now"
        params.join(",\n")
      end

      sig { params(base_fields: T::Array[FieldSpec], event_only: T::Array[FieldSpec]).returns(String) }
      def builder_method_kwargs_from_lists(base_fields, event_only)
        ""
      end

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

      sig { params(template_name: String).returns(String) }
      def header(template_name)
        <<~RUBY.chomp
          # AUTO-GENERATED: DO NOT EDIT
          # Generated by scripts/generate_structs.rb
          # Schemas dir: schemas/log_sources/
          # Template: tools/codegen/templates/sorbet/#{template_name}
        RUBY
      end

      sig { params(partial_name: String).returns(String) }
      def render_partial(partial_name)
        templates_dir = File.join(@root, "tools", "codegen", "templates", "sorbet")
        path = File.join(templates_dir, partial_name)
        erb = ERB.new(File.read(path), trim_mode: "-")
        erb.result(get_binding)
      end

      sig { params(event: T.untyped).returns(String) }
      def render_to_h_partial(event)
        templates_dir = File.join(@root, "tools", "codegen", "templates", "sorbet", "to_h")
        # Try event-specific template first, fall back to _default.rb.erb
        event_specific = File.join(templates_dir, "#{event.name.downcase}.rb.erb")
        default_template = File.join(templates_dir, "_default.rb.erb")

        path = File.exist?(event_specific) ? event_specific : default_template
        erb = ERB.new(File.read(path), trim_mode: "-")
        erb.result(get_binding)
      end
    end
  end
end
