# typed: strict
# frozen_string_literal: true

# External dependencies
require "json"
require "time"
require "securerandom"
require "fileutils"
require "sorbet-runtime"

# We need the LogStruct code from this repo
require_relative "../../../lib/log_struct"

# Load the internal tool files
require_relative "log_generator/config"
require_relative "log_generator/data_generator"
require_relative "log_generator/output_formatter"

# Load the log generators
require_relative "log_generator/generators/base"
require_relative "log_generator/generators/active_job"
require_relative "log_generator/generators/active_storage"
require_relative "log_generator/generators/carrierwave"
require_relative "log_generator/generators/exception"
require_relative "log_generator/generators/plain"
require_relative "log_generator/generators/request"
require_relative "log_generator/generators/security"
require_relative "log_generator/generators/sidekiq"
require_relative "log_generator/generators/shrine"
require_relative "log_generator/generators/action_mailer"

module LogStruct
  module Tools
    # Main class for generating example logs for documentation and testing
    class LogGenerator
      attr_reader :options, :data_generator, :formatter

      # Create a new log generator
      # @param options [Hash] Options to customize the generation
      def initialize(options = {})
        @options = Config::DEFAULT_OPTIONS.merge(options)
        @data_generator = DataGenerator.new
        @formatter = OutputFormatter.new(@options)
      end

      # Generate all examples and write to files
      # @return [Hash] The generated examples
      def generate_all
        # Create output directory if it doesn't exist
        FileUtils.mkdir_p(options[:output_dir])

        # Generate example logs
        examples = generate_all_examples(options[:count])

        # Output the examples in the requested format
        examples.each do |type, logs|
          formatter.output_logs(type, logs)
        end

        # Generate additional combined files
        formatter.generate_combined_files(examples)

        examples
      end

      # Generate examples of all log types
      # @param count [Integer] Number of each log type to generate
      # @return [Hash] Hash of log types with arrays of log entries
      def generate_all_examples(count = 1)
        examples = {
          request: count.times.map { Generators::Request.new(data_generator).generate },
          job: count.times.map { Generators::ActiveJob.new(data_generator).generate },
          mailer: count.times.map { Generators::ActionMailer.new(data_generator).generate },
          error: count.times.map { Generators::Error.new(data_generator).generate },
          security: count.times.map { Generators::Security.new(data_generator).generate },
          shrine: count.times.map { Generators::Shrine.new(data_generator).generate },
          activestorage: count.times.map { Generators::ActiveStorage.new(data_generator).generate },
          sidekiq: count.times.map { Generators::Sidekiq.new(data_generator).generate }
        }

        # Add a complete sequence for a job (enqueue -> process -> complete)
        if count > 0
          examples[:job_sequence] = Generators::ActiveJob.new(data_generator).generate_sequence
        end

        # Make sure all examples are converted to hashes for output
        examples.transform_values! do |logs|
          logs.map do |log|
            log.is_a?(Array) ? log.map(&:serialize) : log.serialize
          end
        end

        examples
      end
    end
  end
end
