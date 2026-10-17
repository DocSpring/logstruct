# typed: strict
# frozen_string_literal: true

require "semantic_logger"
require_relative "formatter"

module LogStruct
  module SemanticLogger
    # Writes lines as pretty-printed JSON in color, for reading in a terminal: keys yellow, strings green, numbers
    # blue, booleans magenta, nil red and logger names cyan (config.color_map changes them). LogStruct uses it in
    # development when LogStruct is enabled there, prefer_json_in_development is false and enable_color_output is
    # true (its default). Messages, payloads, exceptions and tags are scrubbed like the strings in a JSON line.
    class ColorFormatter < ::SemanticLogger::Formatters::Color
      extend T::Sig

      sig { params(color_map: T.nilable(T::Hash[Symbol, Symbol]), args: T.untyped).void }
      def initialize(color_map: nil, **args)
        super(**args)
        @logstruct_formatter = T.let(LogStruct::Formatter.new, LogStruct::Formatter)

        # Set up custom color mapping
        @custom_colors = T.let(default_color_map.merge(color_map || {}), T::Hash[Symbol, Symbol])
      end

      sig { override.params(log: ::SemanticLogger::Log, logger: T.untyped).returns(String) }
      def call(log, logger)
        # Handle LogStruct types specially with colorization
        if log.payload.is_a?(LogStruct::Log::Interfaces::CommonFields)
          formatted = format_logstruct_payload(log)
          formatted if formatted
        elsif log.payload.is_a?(Hash) || log.payload.is_a?(T::Struct)
          formatted = format_logstruct_payload(log)
          formatted if formatted
        else
          # For plain messages, use SemanticLogger's default colorization
          super
        end
      end

      # The parts of a plain line that hold what was logged, scrubbed like the strings in a JSON line
      sig { returns(T.untyped) }
      def message
        scrub_text(super)
      end

      sig { returns(T.untyped) }
      def payload
        scrub_text(super)
      end

      sig { returns(T.untyped) }
      def exception
        scrub_text(super)
      end

      sig { returns(T.untyped) }
      def tags
        scrub_text(super)
      end

      sig { returns(T.untyped) }
      def named_tags
        scrub_text(super)
      end

      private

      sig { params(text: T.untyped).returns(T.untyped) }
      def scrub_text(text)
        text.is_a?(String) ? StringScrubber.scrub(text) : text
      end

      sig { returns(LogStruct::Formatter) }
      attr_reader :logstruct_formatter

      # Default color mapping for LogStruct JSON
      sig { returns(T::Hash[Symbol, Symbol]) }
      def default_color_map
        {
          key: :yellow,
          string: :green,
          number: :blue,
          bool: :magenta,
          nil: :red,
          name: :cyan
        }
      end

      # The line as pretty-printed JSON, with ANSI colors for its keys, strings, numbers, booleans and nulls
      sig { params(data: T::Hash[String, T.untyped]).returns(String) }
      def colorize_json(data)
        json_str = JSON.pretty_generate(data)

        # Apply basic colorization with regex
        json_str.gsub(/"([^"]+)":/, colorize_text('\1', :key) + ":")
          .gsub(/: "([^"]*)"/, ": " + colorize_text('\1', :string))
          .gsub(/: (\d+\.?\d*)/, ": " + colorize_text('\1', :number))
          .gsub(/: (true|false)/, ": " + colorize_text('\1', :bool))
          .gsub(": null", ": " + colorize_text("null", :nil))
      end

      sig { params(log: ::SemanticLogger::Log).returns(T.nilable(String)) }
      def format_logstruct_payload(log)
        logstruct_json = @logstruct_formatter.call(log.level, log.time, log.name, log.payload)

        parsed_data = T.let(JSON.parse(logstruct_json), T::Hash[String, T.untyped])
        colorized_json = colorize_json(parsed_data)

        prefix = format("%<time>s %<level>s [%<process>s] %<name>s -- ",
          time: format_time(log.time),
          level: format_level(log.level),
          process: log.process_info,
          name: format_name(log.name))

        "#{prefix}#{colorized_json}\n"
      rescue JSON::ParserError
        nil
      end

      # Add ANSI color codes to text
      sig { params(text: String, color_type: Symbol).returns(String) }
      def colorize_text(text, color_type)
        color = @custom_colors[color_type] || :white
        "\e[#{color_code_for(color)}m#{text}\e[0m"
      end

      # Format timestamp
      sig { params(time: Time).returns(String) }
      def format_time(time)
        time.strftime("%Y-%m-%d %H:%M:%S.%6N")
      end

      # Format log level with color
      sig { params(level: T.any(String, Symbol)).returns(String) }
      def format_level(level)
        level_str = level.to_s.upcase[0]
        color = level_color_for(level.to_sym)
        "\e[#{color_code_for(color)}m#{level_str}\e[0m"
      end

      # Format logger name with color
      sig { params(name: T.nilable(String)).returns(String) }
      def format_name(name)
        return "" unless name
        color = @custom_colors[:name] || :cyan
        "\e[#{color_code_for(color)}m#{name}\e[0m"
      end

      # Get color for log level
      sig { params(level: Symbol).returns(Symbol) }
      def level_color_for(level)
        case level
        when :debug then :magenta
        when :info then :cyan
        when :warn then :yellow
        when :error then :red
        when :fatal then :red
        else :cyan
        end
      end

      # Get ANSI color code for color symbol
      sig { params(color: Symbol).returns(String) }
      def color_code_for(color)
        case color
        when :black then "30"
        when :red then "31"
        when :green then "32"
        when :yellow then "33"
        when :blue then "34"
        when :magenta then "35"
        when :cyan then "36"
        when :white then "37"
        when :bright_black then "90"
        when :bright_red then "91"
        when :bright_green then "92"
        when :bright_yellow then "93"
        when :bright_blue then "94"
        when :bright_magenta then "95"
        when :bright_cyan then "96"
        when :bright_white then "97"
        else "37" # default to white
        end
      end
    end
  end
end
