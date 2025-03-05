# typed: strict
# frozen_string_literal: true

module LogStruct
  module Tools
    class LogGenerator
      module Generators
        # Base class for all log generators
        class Base
          extend T::Sig

          sig { params(data_generator: LogGenerator::DataGenerator).void }
          def initialize(data_generator)
            @data_generator = data_generator
          end

          # Generate a log entry
          sig { abstract.returns(T::Struct) }
          def generate
          end

          # Helper method that handles all LogStruct::Log types
          # Since CommonFields is sealed, T.absurd will ensure we handle all implementations
          # at compile time, so we can't forget to add example generation for a new log type
          sig { params(log_class: T.class_of(LogStruct::Log::Interfaces::CommonFields)).returns(T.class_of(Base)) }
          def self.get_generator_class_for_log_type(log_class)
            case log_class
            when LogStruct::Log::Plain
              LogGenerator::Generators::Plain
            when LogStruct::Log::Request
              LogGenerator::Generators::Request
            when LogStruct::Log::Error
              LogGenerator::Generators::Error
            when LogStruct::Log::ActiveJob
              LogGenerator::Generators::ActiveJob
            when LogStruct::Log::ActionMailer
              LogGenerator::Generators::ActionMailer
            when LogStruct::Log::Shrine
              LogGenerator::Generators::Shrine
            when LogStruct::Log::Sidekiq
              LogGenerator::Generators::Sidekiq
            when LogStruct::Log::Security
              LogGenerator::Generators::Security
            when LogStruct::Log::ActiveStorage
              LogGenerator::Generators::ActiveStorage
            when LogStruct::Log::CarrierWave
              LogGenerator::Generators::CarrierWave
            else
              # This will fail at compile time if a new LogStruct::Log type is added
              # This ensures we add example generation for all LogStruct::Log types
              T.absurd(log_class)
            end
          end

          protected

          sig { returns(LogGenerator::DataGenerator) }
          attr_reader :data_generator
        end
      end
    end
  end
end
