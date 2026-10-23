#!/usr/bin/env ruby
# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

require_relative "models"
require_relative "schema_loader"
require_relative "helpers"
require_relative "staging"
require "erb"

module LogStruct
  module Codegen
    module TSGenerator
      extend T::Sig

      OUT_DIR = "docs/generated/logstruct"

      sig { params(root: String, staging: Staging).void }
      def self.generate_all(root, staging)
        generate_enums(root, staging)

        SchemaLoader.payloads(root).each do |payload|
          generate_source_ts(root, staging, payload)
        end

        generate_barrel(root, staging)
      end

      sig { params(root: String, staging: Staging).void }
      def self.generate_enums(root, staging)
        template_path = File.join(root, "tools", "codegen", "templates", "typescript", "enums.ts.erb")
        erb = ERB.new(File.read(template_path), trim_mode: "-")
        ctx = Object.new
        ctx.extend(LogStruct::Codegen::Helpers)
        content = erb.result(ctx.instance_eval { binding })
        staging.write(File.join(OUT_DIR, "enums.ts"), content)
      end

      sig { params(payload: SourcePayload).returns(String) }
      def self.ts_source_const(payload)
        payload.source_enum.gsub("::", ".")
      end

      sig { params(name: String).returns(String) }
      def self.snake(name)
        name.gsub(/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
          .gsub(/([a-z\\d])([A-Z])/, "\\1_\\2")
          .downcase
      end

      sig { params(root: String, staging: Staging, payload: SourcePayload).void }
      def self.generate_source_ts(root, staging, payload)
        dir = File.join(OUT_DIR, "sources", payload.source_snake)

        payload.events.each do |evt|
          out = File.join(dir, "#{snake(evt.name)}.ts")
          template_path = File.join(root, "tools", "codegen", "templates", "typescript", "event.ts.erb")
          erb = ERB.new(File.read(template_path), trim_mode: "-")
          ctx = LogStruct::Codegen::TemplateBinding.new(payload, evt, root, {})
          content = erb.result(ctx.get_binding)
          staging.write(out, content)
        end

        template_path = File.join(root, "tools", "codegen", "templates", "typescript", "source_index.ts.erb")
        erb = ERB.new(File.read(template_path), trim_mode: "-")
        ctx = LogStruct::Codegen::TemplateBinding.new(payload, nil, root, {})
        content = erb.result(ctx.get_binding)
        staging.write(File.join(dir, "index.ts"), content)
      end

      sig { params(root: String, staging: Staging).void }
      def self.generate_barrel(root, staging)
        roots = Dir[staging.path(File.join(OUT_DIR, "sources", "*"))].map { |p| File.basename(p) }
        template_path = File.join(root, "tools", "codegen", "templates", "typescript", "root_index.ts.erb")
        erb = ERB.new(File.read(template_path), trim_mode: "-")
        ctx = Object.new
        ctx.extend(LogStruct::Codegen::Helpers)
        ctx.define_singleton_method(:roots) { roots }
        content = erb.result(ctx.instance_eval { binding })
        staging.write(File.join(OUT_DIR, "index.ts"), content)
      end
    end
  end
end
