#!/usr/bin/env ruby
# typed: strict
# frozen_string_literal: true

require "fileutils"
require "erb"
require "sorbet-runtime"

require_relative "models"
require_relative "schema_loader"
require_relative "templates"

module LogStruct
  module Codegen
    module SorbetGenerator
      extend T::Sig

      sig { params(root: String).void }
      def self.generate_all(root)
        out_base_dir = File.join(root, "lib", "log_struct", "log")
        FileUtils.mkdir_p(out_base_dir)

        payloads = SchemaLoader.payloads(root)
        if payloads.empty?
          warn("No schemas found in #{File.join(root, "schemas", "log_sources")}")
          return
        end

        payloads.each do |payload|
          generate_source(root, out_base_dir, payload)
        end
      end

      sig { params(root: String, out_base_dir: String, payload: SourcePayload).void }
      def self.generate_source(root, out_base_dir, payload)
        source_snake = payload.source_snake
        source_dir = File.join(out_base_dir, source_snake)

        if payload.events.size == 1
          evt = T.must(payload.events.first)
          single_out = File.join(out_base_dir, "#{source_snake}.rb")
          single_content = render_template(root, "event.rb.erb", {payload: payload, event: evt, single_event: true})
          File.write(single_out, single_content)
          puts "Generated: #{single_out}"
        else
          FileUtils.mkdir_p(source_dir)

          payload.events.each do |evt|
            ev_out = File.join(source_dir, "#{LogStruct::Codegen.snake_case(evt.name)}.rb")
            ev_content = render_template(root, "event.rb.erb", {payload: payload, event: evt, single_event: false})
            File.write(ev_out, ev_content)
            puts "Generated: #{ev_out}"
          end

          parent_out = File.join(out_base_dir, "#{source_snake}.rb")
          parent_content = render_template(root, "source_parent.rb.erb", {payload: payload})
          File.write(parent_out, parent_content)
          puts "Generated: #{parent_out}"
        end
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
