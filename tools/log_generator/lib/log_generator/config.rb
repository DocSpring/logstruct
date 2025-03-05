# typed: strict
# frozen_string_literal: true

module LogStruct
  module Tools
    class LogGenerator
      # Configuration constants and default settings
      module Config
        DEFAULT_OPTIONS = {
          output_dir: "site/public/example_logs",
          count: 1,
          format: "json"
        }.freeze
      end
    end
  end
end