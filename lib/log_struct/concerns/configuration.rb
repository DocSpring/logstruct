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
          # Set enabled based on current Rails environment.
          # (Users can disable or enable LogStruct later in an initializer.)
          config.enabled = config.enabled_environments.include?(::Rails.env.to_sym)
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
