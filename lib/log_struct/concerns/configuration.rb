# typed: strict
# frozen_string_literal: true

module LogStruct
  module Concerns
    # Concern for handling errors according to configured modes
    module Configuration
      extend T::Sig

      sig { returns(T::Boolean) }
      def enabled?
        LogStruct.enabled?
      end
    end
  end
