# typed: strict
# frozen_string_literal: true

require "minitest/autorun"
require "json_schemer"
require "yaml"

class SchemaValidationTest < Minitest::Test
  extend T::Sig

  sig { void }
  def test_log_source_schemas_are_valid
    root = File.expand_path("../..", __dir__)
    schema_path = File.join(root, "schemas", "meta", "log-source-schema.json")
    schemer = JSONSchemer.schema(Pathname.new(schema_path))

    Dir[File.join(root, "schemas", "log_sources", "*.{yml,yaml}")].sort.each do |yml|
      data = YAML.safe_load_file(yml)
      errors = schemer.validate(data).to_a

      assert_empty errors, format_errors(yml, errors)
    end
  end

  private

  sig { params(file: String, errors: T::Array[T::Hash[String, T.untyped]]).returns(String) }
  def format_errors(file, errors)
    lines = ["Schema validation failed for #{relative(file)}:"]
    errors.first(20).each do |err|
      path = (err["data_pointer"] || "").sub(%r{^/}, "").tr("/", ".")
      lines << "- #{path}: #{err["type"]} #{err["details"] || {}}"
    end
    lines.join("\n")
  end

  sig { params(path: String).returns(String) }
  def relative(path)
    Pathname.new(path).relative_path_from(Pathname.new(File.expand_path("../..", __dir__))).to_s
  end
end
