#!/usr/bin/env ruby
# typed: strict
# frozen_string_literal: true

require "fileutils"
require "sorbet-runtime"

require_relative "models"
require_relative "schema_loader"
require_relative "helpers"
require "erb"

module LogStruct
  module Codegen
    module TSGenerator
      extend T::Sig

      sig { params(root: String).void }
      def self.generate_all(root)
        out_dir = File.join(root, "docs", "generated", "logstruct")
        FileUtils.rm_rf(out_dir)
        FileUtils.mkdir_p(out_dir)

        generate_enums(root, out_dir)

        SchemaLoader.payloads(root).each do |payload|
          generate_source_ts(root, out_dir, payload)
        end

        generate_barrel(root, out_dir)
      end

      sig { params(root: String, out_dir: String).void }
      def self.generate_enums(root, out_dir)
        template_path = File.join(root, "tools", "codegen", "templates", "typescript", "enums.ts.erb")
        erb = ERB.new(File.read(template_path), trim_mode: "-")
        ctx = Object.new
        ctx.extend(LogStruct::Codegen::Helpers)
        content = erb.result(ctx.instance_eval { binding })
        File.write(File.join(out_dir, "enums.ts"), content)
      end

      sig { params(payload: SourcePayload).returns(String) }
      def self.ts_source_const(payload)
        payload.source_enum.gsub("::", ".")
      end

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
        name.gsub(/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
          .gsub(/([a-z\\d])([A-Z])/, "\\1_\\2")
          .downcase
      end

      sig { params(root: String, out_dir: String, payload: SourcePayload).void }
      def self.generate_source_ts(root, out_dir, payload)
        dir = File.join(out_dir, "sources", payload.source_snake)
        FileUtils.mkdir_p(dir)

        payload.events.each do |evt|
          out = File.join(dir, "#{snake(evt.name)}.ts")
          template_path = File.join(root, "tools", "codegen", "templates", "typescript", "event.ts.erb")
          erb = ERB.new(File.read(template_path), trim_mode: "-")
          ctx = LogStruct::Codegen::TemplateBinding.new(payload, evt, root, {})
          content = erb.result(ctx.get_binding)
          File.write(out, content)
        end

        template_path = File.join(root, "tools", "codegen", "templates", "typescript", "source_index.ts.erb")
        erb = ERB.new(File.read(template_path), trim_mode: "-")
        ctx = LogStruct::Codegen::TemplateBinding.new(payload, nil, root, {})
        content = erb.result(ctx.get_binding)
        File.write(File.join(dir, "index.ts"), content)
      end

      sig { params(root: String, out_dir: String).void }
      def self.generate_barrel(root, out_dir)
        roots = Dir[File.join(out_dir, "sources", "*")].map { |p| File.basename(p) }
        template_path = File.join(root, "tools", "codegen", "templates", "typescript", "root_index.ts.erb")
        erb = ERB.new(File.read(template_path), trim_mode: "-")
        ctx = Object.new
        ctx.extend(LogStruct::Codegen::Helpers)
        ctx.define_singleton_method(:roots) { roots }
        content = erb.result(ctx.instance_eval { binding })
        File.write(File.join(out_dir, "index.ts"), content)
      end
    end
  end
end
