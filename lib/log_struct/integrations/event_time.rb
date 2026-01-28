# typed: strict
# frozen_string_literal: true

module LogStruct
  module Integrations
    module EventTime
      extend T::Sig

      sig { params(value: T.untyped).returns(Time) }
      def self.coerce_event_time(value)
        return value if value.is_a?(Time)
        return Time.now unless value.is_a?(Numeric)

        monotonic_now = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
        Time.now - (monotonic_now - value)
      end
    end
  end
end
