# typed: strict
# frozen_string_literal: true

module LogStruct
  module Tools
    class LogGenerator
      # Handles formatting and output of generated logs
      class OutputFormatter
        attr_reader :options
        
        # Initialize with options
        # @param options [Hash] Options for formatting and output
        def initialize(options)
          @options = options
        end
        
        # Output logs to files in the specified format
        # @param type [Symbol] The type of logs
        # @param logs [Array] The logs to output
        def output_logs(type, logs)
          case options[:format]
          when "json"
            file_path = File.join(options[:output_dir], "#{type}.json")
            File.write(file_path, JSON.pretty_generate(logs))
          when "yaml"
            require "yaml"
            file_path = File.join(options[:output_dir], "#{type}.yml")
            File.write(file_path, logs.to_yaml)
          when "ruby"
            file_path = File.join(options[:output_dir], "#{type}.rb")
            File.write(file_path, "[\n  " + logs.map { |log| log.inspect }.join(",\n  ") + "\n]")
          end
        end
        
        # Generate combined files from examples
        # @param examples [Hash] All generated examples
        def generate_combined_files(examples)
          # Create a combined examples file with one of each type
          all_examples = examples.transform_values { |logs| logs.first }
          combined_file_path = File.join(options[:output_dir], "examples.json")
          File.write(combined_file_path, JSON.pretty_generate(all_examples))
          
          # Add seed file so we can reproduce these examples
          if options[:seed]
            seed_file_path = File.join(options[:output_dir], "seed.json")
            File.write(seed_file_path, JSON.pretty_generate({ seed: options[:seed] }))
          end

          # Create a log scroller samples file
          log_scroller_samples = []
          examples.each do |type, logs|
            next if type == :job_sequence # Skip the special sequence
            log_scroller_samples << logs.first if logs.any?
          end
          log_scroller_file_path = File.join(options[:output_dir], "log_scroller_samples.json")
          File.write(log_scroller_file_path, JSON.pretty_generate(log_scroller_samples.shuffle(random: Random.new(options[:seed] || 42))))
        end
      end
    end
  end
end