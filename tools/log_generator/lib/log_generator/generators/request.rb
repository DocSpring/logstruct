# typed: strict
# frozen_string_literal: true

module LogStruct
  module Tools
    class LogGenerator
      module Generators
        # Generator for LogStruct::Log::Request logs
        class Request < Base
          extend T::Sig

          # Generate a request log entry
          sig { override.returns(LogStruct::Log::Request) }
          def generate
            LogStruct::Log::Request.new(
              source: LogStruct::Source::Rails,
              method: data_generator.choice(DataGenerator::HTTP_METHODS),
              path: data_generator.random_path,
              controller: data_generator.choice(DataGenerator::CONTROLLERS),
              action: data_generator.choice(DataGenerator::ACTIONS),
              status: data_generator.choice(DataGenerator::STATUS_CODES),
              duration_ms: data_generator.random_duration,
              remote_ip: data_generator.random_ip
            )
          end
        end
      end
    end
  end
end