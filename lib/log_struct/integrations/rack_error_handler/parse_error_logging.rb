# typed: strict
# frozen_string_literal: true

module LogStruct
  module Integrations
    module RackErrorHandler
      # Prepended to ActionDispatch::Request. When Rails can't parse a request's body (malformed JSON), it logs the
      # whole body at debug level, where nothing filters it. LogStruct logs the body's size and type instead. The
      # request line and the ParseError's error line are written as usual.
      module ParseErrorLogging
        extend T::Sig
        extend T::Helpers

        requires_ancestor { ::ActionDispatch::Request }

        private

        sig { returns(T.untyped) }
        def log_parse_error_once
          return super unless ErrorLines.enabled?

          @logstruct_parse_error_logged ||= T.let(
            begin
              (logger || ::ActiveSupport::Logger.new($stderr)).debug(
                "Error occurred while parsing request parameters. LogStruct leaves out the body " \
                "(#{raw_post.to_s.bytesize} bytes of #{media_type}), which it can't filter."
              )
              true
            end,
            T.nilable(TrueClass)
          )
        end
      end
    end
  end
end
