# typed: strict
# frozen_string_literal: true

require_relative "../configuration"

module LogStruct
  module Concerns
    # Concern for handling errors according to configured modes
    module Configuration
      module ClassMethods
        extend T::Sig

        SERVER_COMMAND_ARGS = T.let(["server", "s"].freeze, T::Array[String])
        CONSOLE_COMMAND_ARGS = T.let(["console", "c"].freeze, T::Array[String])
        EMPTY_ARGV = T.let([].freeze, T::Array[String])
        CI_FALSE_VALUES = T.let(["false", "0", "no"].freeze, T::Array[String])

        sig { params(block: T.proc.params(config: LogStruct::Configuration).void).void }
        def configure(&block)
          yield(config)
        end

        sig { returns(LogStruct::Configuration) }
        def config
          LogStruct::Configuration.instance
        end

        # (Can't use alias_method since this module is extended into LogStruct)
        sig { returns(LogStruct::Configuration) }
        def configuration
          config
        end

        # Setter method to replace the configuration (for testing purposes)
        sig { params(config: LogStruct::Configuration).void }
        def configuration=(config)
          LogStruct::Configuration.set_instance(config)
        end

        sig { returns(T::Boolean) }
        def enabled?
          config.enabled
        end

        sig { void }
        def set_enabled_from_rails_env!
          # Set enabled based on current Rails environment and the LOGSTRUCT_ENABLED env var.
          # Precedence:
          # 1. Check if LOGSTRUCT_ENABLED env var is defined (not an empty string)
          #    - Sets enabled=true only when value is "true", "yes", "1", etc.
          #    - Sets enabled=false when value is any other value
          # 2. Otherwise, check if current Rails environment is in enabled_environments
          #    AND one of: Rails::Server is defined, OR test environment with CI=true
          #    BUT NOT Rails::Console (to exclude interactive console)
          # 3. Otherwise, leave as config.enabled (defaults to true)

          # Then check if LOGSTRUCT_ENABLED env var is set
          config.enabled = if ENV["LOGSTRUCT_ENABLED"]
            %w[true t yes y 1].include?(ENV["LOGSTRUCT_ENABLED"]&.strip&.downcase)
          else
            is_console = console_process?
            is_server = server_process?
            is_ci = ci_build?
            in_enabled_env = config.enabled_environments.include?(::Rails.env.to_sym)

            in_enabled_env && !is_console && (is_server || (::Rails.env.test? && is_ci))
          end
        end

        sig { returns(T::Boolean) }
        def is_local?
          config.local_environments.include?(::Rails.env.to_sym)
        end

        sig { returns(T::Boolean) }
        def is_production?
          !is_local?
        end

        sig { void }
        def merge_rails_filter_parameters!
          return unless ::Rails.application.config.respond_to?(:filter_parameters)

          rails_filter_params = ::Rails.application.config.filter_parameters
          return unless rails_filter_params.is_a?(Array)
          return if rails_filter_params.empty?

          symbol_filters = T.let([], T::Array[Symbol])
          matchers = T.let([], T::Array[ConfigStruct::FilterMatcher])
          leftovers = T.let([], T::Array[T.untyped])

          rails_filter_params.each do |entry|
            matcher = build_filter_matcher(entry)

            if matcher
              matchers << matcher
              next
            end

            normalized_symbol = normalize_filter_symbol(entry)
            if normalized_symbol
              symbol_filters << normalized_symbol
            else
              leftovers << entry
            end
          end

          if symbol_filters.any?
            config.filters.filter_keys |= symbol_filters
          end

          if matchers.any?
            matchers.each do |matcher|
              existing = config.filters.filter_matchers.any? do |registered|
                registered.label == matcher.label
              end
              config.filters.filter_matchers << matcher unless existing
            end
          end

          replace_filter_parameters(rails_filter_params, leftovers)
        end

        private

        sig { returns(T::Boolean) }
        def console_process?
          return true if defined?(::Rails::Console)

          current_argv.any? { |arg| CONSOLE_COMMAND_ARGS.include?(arg) }
        end

        sig { returns(T::Boolean) }
        def server_process?
          return true if logstruct_server_mode?

          current_argv.any? { |arg| SERVER_COMMAND_ARGS.include?(arg) }
        end

        sig { returns(T::Boolean) }
        def logstruct_server_mode?
          ::LogStruct.server_mode?
        end

        sig { returns(T::Array[String]) }
        def current_argv
          raw = ::ARGV
          strings = raw.map { |arg| arg.to_s }
          T.let(strings, T::Array[String])
        rescue NameError
          EMPTY_ARGV
        end

        sig { returns(T::Boolean) }
        def ci_build?
          value = ENV["CI"]
          return false if value.nil?

          normalized = value.strip.downcase
          return false if normalized.empty?

          !CI_FALSE_VALUES.include?(normalized)
        end

        sig { params(filter: T.untyped).returns(T.nilable(Symbol)) }
        def normalize_filter_symbol(filter)
          return filter if filter.is_a?(Symbol)
          return filter.downcase.to_sym if filter.is_a?(String)

          return nil unless filter.respond_to?(:to_sym)

          begin
            sym = filter.to_sym
            sym.is_a?(Symbol) ? sym : nil
          rescue
            nil
          end
        end

        sig { params(filter: T.untyped).returns(T.nilable(ConfigStruct::FilterMatcher)) }
        def build_filter_matcher(filter)
          case filter
          when ::Regexp
            callable = Kernel.lambda do |key, _value|
              filter.match?(key)
            end
            return ConfigStruct::FilterMatcher.new(callable: callable, label: filter.inspect)
          else
            return build_callable_filter_matcher(filter) if callable_filter?(filter)
          end

          nil
        end

        sig { params(filter: T.untyped).returns(T::Boolean) }
        def callable_filter?(filter)
          filter.respond_to?(:call)
        end

        sig { params(filter: T.untyped).returns(T.nilable(ConfigStruct::FilterMatcher)) }
        def build_callable_filter_matcher(filter)
          callable = Kernel.lambda do |key, value|
            call_args = case arity_for_filter(filter)
            when 0
              []
            when 1
              [key]
            else
              [key, value]
            end

            result = filter.call(*call_args)
            !!result
          rescue ArgumentError
            begin
              !!filter.call(key)
            rescue => e
              handle_filter_error(e, filter, key)
              false
            end
          rescue => e
            handle_filter_error(e, filter, key)
            false
          end
          ConfigStruct::FilterMatcher.new(callable: callable, label: filter.inspect)
        end

        sig { params(filter: T.untyped).returns(Integer) }
        def arity_for_filter(filter)
          filter.respond_to?(:arity) ? filter.arity : 2
        end

        sig { params(filter_params: T::Array[T.untyped], leftovers: T::Array[T.untyped]).void }
        def replace_filter_parameters(filter_params, leftovers)
          filter_params.clear
          filter_params.concat(leftovers)
        end

        sig { params(error: StandardError, filter: T.untyped, key: String).void }
        def handle_filter_error(error, filter, key)
          context = {
            filter: filter.class.name,
            key: key,
            filter_label: begin
              filter.inspect
            rescue
              "unknown"
            end
          }

          LogStruct.handle_exception(error, source: Source::Internal, context: context)
        end
      end
    end
  end
end
