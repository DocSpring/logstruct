#!/usr/bin/env ruby
# typed: strict
# frozen_string_literal: true

require "erb"
require "sorbet-runtime"

require_relative "models"
require_relative "schema_loader"
require_relative "staging"
require_relative "templates"

module LogStruct
  module Codegen
    module SorbetGenerator
      extend T::Sig

      OUT_DIR = "lib/log_struct/log"

      # Returns the generated files' paths in the repository
      sig { params(root: String, staging: Staging).returns(T::Array[String]) }
      def self.generate_all(root, staging)
        payloads = SchemaLoader.payloads(root)
        if payloads.empty?
          warn("No schemas found in #{File.join(root, "schemas", "log_sources")}")
          return []
        end

        payloads.flat_map do |payload|
          generate_source(root, staging, payload)
        end
      end

      sig { params(root: String, staging: Staging, payload: SourcePayload).returns(T::Array[String]) }
      def self.generate_source(root, staging, payload)
        source_snake = payload.source_snake

        if payload.events.size == 1
          evt = T.must(payload.events.first)
          single_content = render_template(root, "event.rb.erb", {payload: payload, event: evt, single_event: true})
          [write(staging, "#{source_snake}.rb", single_content)]
        else
          files = payload.events.map do |evt|
            ev_content = render_template(root, "event.rb.erb", {payload: payload, event: evt, single_event: false})
            write(staging, File.join(source_snake, "#{LogStruct::Codegen.snake_case(evt.name)}.rb"), ev_content)
          end

          parent_content = render_template(root, "source_parent.rb.erb", {payload: payload})
          files << write(staging, "#{source_snake}.rb", parent_content)
        end
      end

      sig { params(staging: Staging, file: String, content: String).returns(String) }
      def self.write(staging, file, content)
        relative_path = File.join(OUT_DIR, file)
        staging.write(relative_path, content)
        puts "Generated: #{relative_path}"
        relative_path
      end

      sig { params(root: String, template_name: String, locals: T::Hash[Symbol, T.untyped]).returns(String) }
      def self.render_template(root, template_name, locals)
        payload = T.cast(locals[:payload], SourcePayload)
        ev = locals.key?(:event) ? T.cast(locals[:event], T.nilable(EventSpec)) : nil
        extras = locals.dup
        extras.delete(:payload)
        extras.delete(:event)
        ctx = TemplateBinding.new(payload, ev, root, extras)

        template_path = File.join(root, "tools", "codegen", "templates", "sorbet", template_name)
        erb = ERB.new(File.read(template_path), trim_mode: "-")
        erb.result(ctx.get_binding)
      end
    end
  end
end
