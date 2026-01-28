# typed: strict
# frozen_string_literal: true

module LogStruct
  module Integrations
    module RackSetup
      extend T::Sig

      sig { params(config: LogStruct::Configuration).returns(T::Boolean) }
      def self.enabled?(config)
        return false unless config.enabled
        return false unless config.integrations.enable_rack_error_handler

        true
      end

      sig { params(anchor: T.untyped, middleware: T.untyped).void }
      def self.insert_after(anchor, middleware)
        ::Rails.application.middleware.insert_after(anchor, middleware)
      end

      sig { params(anchor: T.untyped, middleware: T.untyped).void }
      def self.insert_before(anchor, middleware)
        ::Rails.application.middleware.insert_before(anchor, middleware)
      end
    end
  end
end
