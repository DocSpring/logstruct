# frozen_string_literal: true
# typed: strict

require_relative '../sorbet'

module RailsStructuredLogging
  module ActionMailer
    # Backport of the *_deliver callbacks from Rails 7.1
    module Callbacks
      include RailsStructuredLogging::TypedSig
      extend T::Sig
      extend ActiveSupport::Concern

      included do
        include ActiveSupport::Callbacks
        define_callbacks :deliver, skip_after_callbacks_if_terminated: true
      end

      class_methods do
        extend T::Sig

        # Defines a callback that will get called right before the
        # message is sent to the delivery method.
        sig { params(filters: T.untyped, blk: T.nilable(T.proc.bind(T.untyped).void)).void }
        def before_deliver(*filters, &blk)
          set_callback(:deliver, :before, *filters, &blk)
        end

        # Defines a callback that will get called right after the
        # message's delivery method is finished.
        sig { params(filters: T.untyped, blk: T.nilable(T.proc.bind(T.untyped).void)).void }
        def after_deliver(*filters, &blk)
          set_callback(:deliver, :after, *filters, &blk)
        end

        # Defines a callback that will get called around the message's deliver method.
        sig { params(filters: T.untyped, blk: T.nilable(T.proc.bind(T.untyped).params(arg0: T.untyped).void)).void }
        def around_deliver(*filters, &blk)
          set_callback(:deliver, :around, *filters, &blk)
        end
      end

      # Patch MessageDelivery to run the callbacks
      sig { void }
      def self.patch_message_delivery
        ::ActionMailer::MessageDelivery.class_eval do
          # Override deliver_now to run callbacks
          def deliver_now
            processed_mailer.handle_exceptions do
              processed_mailer.run_callbacks(:deliver) do
                message.deliver
              end
            end
          end

          # Override deliver_now! to run callbacks
          def deliver_now!
            processed_mailer.handle_exceptions do
              processed_mailer.run_callbacks(:deliver) do
                message.deliver!
              end
            end
          end
        end
      end
    end
  end
end
