# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  module CodeExamples
    class ExhaustivenessTest < ActiveSupport::TestCase
      ROOT = File.expand_path("../..", __dir__)
      EXAMPLE_FILE = File.join(ROOT, "test", "code_examples", "configuration_test.rb")

      def test_integrations_configuration_is_exhaustive
        block = extract_example_block("integrations_configuration")
        props = props_from_struct(File.join(ROOT, "lib", "log_struct", "config_struct", "integrations.rb"))
          .select { |p| p.start_with?("enable_") }

        assert_props_present!(
          block: block,
          props: props,
          prefixes: ["config.integrations."],
          hint: "config.integrations.NAME_HERE = true"
        )
      end

      def test_filter_configuration_is_exhaustive
        block = extract_example_block("filter_configuration")
        props = props_from_struct(File.join(ROOT, "lib", "log_struct", "config_struct", "filters.rb"))

        assert_props_present!(
          block: block,
          props: props,
          prefixes: ["config.filters."],
          hint: "config.filters.NAME_HERE = ..."
        )
      end

      def test_error_handling_modes_configuration_is_exhaustive
        block = extract_example_block("error_handling_modes")
        props = props_from_struct(File.join(ROOT, "lib", "log_struct", "config_struct", "error_handling_modes.rb"))

        # Accept either `modes.<name>` or `config.error_handling_modes.<name>`
        assert_props_present!(
          block: block,
          props: props,
          prefixes: ["modes.", "config.error_handling_modes."],
          hint: "modes.NAME_HERE = LogStruct::ErrorHandlingMode::..."
        )
      end

      private

      def extract_example_block(id)
        content = File.read(EXAMPLE_FILE)
        begin_marker = /\bBEGIN CODE EXAMPLE:\s*#{Regexp.escape(id)}\b/
        end_marker = /\bEND CODE EXAMPLE:\s*#{Regexp.escape(id)}\b/

        start_idx = content.index(begin_marker)

        assert start_idx, "BEGIN marker for #{id} not found in #{EXAMPLE_FILE}"
        after_start = content[start_idx..]

        end_idx = after_start.index(end_marker)

        assert end_idx, "END marker for #{id} not found in #{EXAMPLE_FILE}"

        after_start[0...end_idx]
      end

      def props_from_struct(path)
        File.read(path)
          .each_line
          .filter_map { |line| (m = line.match(/\bprop\s+:([a-z0-9_]+)\b/)) && m[1] }
          .uniq
      end

      def assert_props_present!(block:, props:, prefixes:, hint:)
        missing = props.reject do |name|
          prefixes.any? { |pref| block.include?("#{pref}#{name}") }
        end

        assert_empty missing, <<~MSG
          Missing settings in code example:\n\n  - #{missing.join("\n  - ")}\n\n          Add lines like:\n            #{hint}\n\n          Example location: #{EXAMPLE_FILE}
        MSG
      end
    end
  end
end
