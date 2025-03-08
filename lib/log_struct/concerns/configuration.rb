# typed: strict
# frozen_string_literal: true

require_relative "../configuration"

module LogStruct
  module Concerns
    # Concern for handling errors according to configured modes
    module Configuration
      module ClassMethods
        extend T::Sig

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
          # 1. Check if current Rails environment is in enabled_environments
          # 2. Check if LOGSTRUCT_ENABLED env var is set to "true"
          # 3. Default to whatever is set in config.enabled (which defaults to true)

          # First check if current Rails environment is in enabled_environments
          rails_env_enabled = config.enabled_environments.include?(::Rails.env.to_sym)

          # Then check if LOGSTRUCT_ENABLED env var is set
          env_var_enabled = if !rails_env_enabled && ENV["LOGSTRUCT_ENABLED"]
            # Only override if env var is "true"
            ENV["LOGSTRUCT_ENABLED"] == "true"
          else
            # If rails_env_enabled is true or ENV var is not set, use rails_env_enabled
            rails_env_enabled
          end

          # Set enabled based on the determined value
          config.enabled = env_var_enabled
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

          # Convert all Rails filter parameters to symbols and merge with our filter keys
          converted_params = rails_filter_params.map do |param|
            param.respond_to?(:to_sym) ? param.to_sym : param
          end

          # Add Rails filter parameters to our filter keys
          config.filters.filter_keys += converted_params

          # Ensure no duplicates
          config.filters.filter_keys.uniq!

          # Clear Rails filter parameters since we've incorporated them
          ::Rails.application.config.filter_parameters.clear
        end
      end
    end
  end
end
