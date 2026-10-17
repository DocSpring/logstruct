# typed: strict
# frozen_string_literal: true

require "active_support/parameter_filter"
require "active_support/core_ext/object/duplicable"
require_relative "../configuration"

module LogStruct
  module Concerns
    # Concern for handling errors according to configured modes
    module Configuration
      module ClassMethods
        extend T::Sig

        CONSOLE_COMMAND_ARGS = T.let(["console", "c"].freeze, T::Array[String])
        EMPTY_ARGV = T.let([].freeze, T::Array[String])
        CI_FALSE_VALUES = T.let(["false", "0", "no"].freeze, T::Array[String])
        RAILS_PATTERNS_LABEL = "Rails filter_parameters"
        RAILS_REGEXPS_LABEL = "Rails filter_parameters (Regexps)"
        RAILS_PATTERN_LABELS = T.let([RAILS_PATTERNS_LABEL, RAILS_REGEXPS_LABEL].freeze, T::Array[String])
        RAILS_FILTER_MASK = "[FILTERED]"
        RAILS_FILTER_PROBE = "value"

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
          env_var_enabled = enabled_from_env_var
          config.enabled = if env_var_enabled.nil?
            is_console = console_process?
            is_server = server_process?
            ci_build?
            in_enabled_env = config.enabled_environments.include?(::Rails.env.to_sym)

            in_enabled_env && !is_console && (is_server || ::Rails.env.test?)
          else
            env_var_enabled
          end

          # apply_initializer_settings! compares the settings with these
          @enabled_from_rails_env = T.let(config.enabled, T.nilable(T::Boolean))
          @enabled_environments_from_rails_env = T.let(config.enabled_environments.dup, T.nilable(T::Array[Symbol]))
        end

        # After config/initializers run: LOGSTRUCT_ENABLED takes precedence, then `config.enabled`
        # if an initializer changed it, then `config.enabled_environments` if an initializer changed that
        sig { void }
        def apply_initializer_settings!
          env_var_enabled = enabled_from_env_var
          if !env_var_enabled.nil?
            config.enabled = env_var_enabled
          elsif config.enabled == @enabled_from_rails_env && config.enabled_environments != @enabled_environments_from_rails_env
            set_enabled_from_rails_env!
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

          blocks, patterns = rails_filter_params.partition { |entry| callable_filter?(entry) }
          regexps, partial_names = patterns.partition { |entry| entry.is_a?(Regexp) }
          matchers = blocks.map { |block| build_callable_filter_matcher(block) }
          if partial_names.any?
            matchers << build_rails_pattern_matcher(partial_names, label: RAILS_PATTERNS_LABEL, matches_logstruct_fields: false)
          end
          if regexps.any?
            matchers << build_rails_pattern_matcher(regexps, label: RAILS_REGEXPS_LABEL, matches_logstruct_fields: true)
          end

          # Exact names also filter LogStruct's own fields, which the partial matches skip
          names = patterns.filter_map { |entry| entry.to_s.downcase.to_sym if entry.is_a?(Symbol) || entry.is_a?(String) }
          config.filters.filter_keys |= names

          registered = config.filters.filter_matchers
          # The latest list replaces the patterns merged before
          registered.reject! { |matcher| RAILS_PATTERN_LABELS.include?(matcher.label) }
          matchers.each do |matcher|
            registered << matcher unless registered.any? { |existing| existing.label == matcher.label }
          end
        end

        private

        sig { returns(T.nilable(T::Boolean)) }
        def enabled_from_env_var
          value = ENV["LOGSTRUCT_ENABLED"]
          return nil if value.nil?

          %w[true t yes y 1].include?(value.strip.downcase)
        end

        sig { returns(T::Boolean) }
        def console_process?
          return true if defined?(::Rails::Console)

          current_argv.any? { |arg| CONSOLE_COMMAND_ARGS.include?(arg) }
        end

        sig { returns(T::Boolean) }
        def server_process?
          return true if logstruct_server_mode?
          return true if puma_server?
          return true if defined?(::Unicorn::HttpServer)
          return true if defined?(::Thin::Server)
          return true if defined?(::Falcon::Server)
          return true if defined?(::Rails::Server)
          return true if sidekiq_server?

          false
        end

        sig { returns(T::Boolean) }
        def puma_server?
          # Just checking defined?(::Puma::Server) is not reliable - Puma might be installed
          # but not running. Check $PROGRAM_NAME and ARGV to verify we're actually running puma.
          # ARGV check is needed when running through wrapper scripts like gosu.
          return true if $PROGRAM_NAME.include?("puma")
          return true if current_argv.any? { |arg| arg.include?("puma") }

          false
        end

        sig { returns(T::Boolean) }
        def sidekiq_server?
          !!(defined?(::Sidekiq) && ::Sidekiq.respond_to?(:server?) && ::Sidekiq.server?)
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

        # Rails matches Symbols and Strings as case-insensitive substrings (:passw filters
        # "user_password") and Regexps as they are. Entries with a dot match nested request
        # parameters by their path in Rails. LogStruct checks one key at a time, so they only
        # match a key that contains the whole path.
        #
        # The substring matches skip LogStruct's own fields (Rails' :_key would hide GoodJob's
        # cron_key); their exact names are added to filter_keys instead. A Regexp says exactly
        # what it matches, so Regexps apply to every key, LogStruct's fields included.
        sig { params(patterns: T::Array[T.untyped], label: String, matches_logstruct_fields: T::Boolean).returns(ConfigStruct::FilterMatcher) }
        def build_rails_pattern_matcher(patterns, label:, matches_logstruct_fields:)
          parameter_filter = ::ActiveSupport::ParameterFilter.new(patterns, mask: RAILS_FILTER_MASK)
          callable = Kernel.lambda do |key, _value|
            parameter_filter.filter_param(key, RAILS_FILTER_PROBE) == RAILS_FILTER_MASK
          end
          ConfigStruct::FilterMatcher.new(callable: callable, label: label, matches_logstruct_fields: matches_logstruct_fields)
        end

        sig { params(filter: T.untyped).returns(T::Boolean) }
        def callable_filter?(filter)
          filter.respond_to?(:call)
        end

        # Rails gives filter blocks copies of the key and value, ignores what they return, and
        # logs the value as the block left it: the Rails guides' example reverses it in place,
        # and a block can replace it with "[FILTERED]". LogStruct filters a key when its block
        # returns a truthy value or changes a String it's given, and never changes the logged
        # value itself. Rails passes blocks with three arguments the request's parameters as
        # well; LogStruct checks one key at a time, so they get an empty Hash.
        sig { params(filter: T.untyped).returns(ConfigStruct::FilterMatcher) }
        def build_callable_filter_matcher(filter)
          callable = Kernel.lambda do |original_key, original_value|
            key = original_key.dup
            value = original_value.duplicable? ? original_value.dup : original_value
            call_args = case arity_for_filter(filter)
            when 0
              []
            when 1
              [key]
            when 3
              [key, value, {}]
            else
              [key, value]
            end

            result = filter.call(*call_args)
            !!result || (value.is_a?(String) && value != original_value)
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
