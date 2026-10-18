# typed: strict
# frozen_string_literal: true

module LogStruct
  module Integrations
    module ActionMailer
      # The error handlers a mailer can name in rescue_from (with: :log_and_ignore_error), for processes
      # where LogStruct doesn't set up ActionMailer (development, the console and Rake tasks by default).
      # Without them those mailers raised NameError there. Each logs the error with the mailer's logger,
      # then ignores it, reports it to Rails.error, or raises it again, as its name says.
      module FallbackErrorHandlers
        extend T::Sig
        extend T::Helpers

        requires_ancestor { ::ActionMailer::Base }

        class << self
          extend T::Sig

          sig { params(logger: T.untyped, error: StandardError, report: T::Boolean, reraise: T::Boolean).void }
          def handle(logger, error, report:, reraise:)
            logger&.error("#{error.class}: #{error.message}")
            ::Rails.error.report(error, handled: true, source: "logstruct.action_mailer") if report
            Kernel.raise error if reraise
          end
        end

        # The handlers, for a mailer and (through ClassMethods) for the mailer class, which
        # ActionMailer::MailDeliveryJob passes an error to. Both have a logger.
        module Handlers
          extend T::Sig
          extend T::Helpers

          abstract!

          sig { params(ex: StandardError).void }
          def log_and_ignore_error(ex)
            FallbackErrorHandlers.handle(handler_logger, ex, report: false, reraise: false)
          end

          sig { params(ex: StandardError).void }
          def log_and_report_error(ex)
            FallbackErrorHandlers.handle(handler_logger, ex, report: true, reraise: false)
          end

          sig { params(ex: StandardError).void }
          def log_and_reraise_error(ex)
            FallbackErrorHandlers.handle(handler_logger, ex, report: false, reraise: true)
          end

          private

          sig { abstract.returns(T.untyped) }
          def handler_logger
          end
        end

        include Handlers

        module ClassMethods
          extend T::Sig
          extend T::Helpers

          requires_ancestor { T.class_of(::ActionMailer::Base) }

          include Handlers

          private

          sig { override.returns(T.untyped) }
          def handler_logger = logger
        end

        private

        sig { override.returns(T.untyped) }
        def handler_logger = logger
      end
    end
  end
end
