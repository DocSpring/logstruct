# typed: true
# frozen_string_literal: true

module LogStruct
  module Integrations
    module ActionMailer
      # Backport of the *_deliver callbacks from Rails 7.1
      module Callbacks
        extend ::ActiveSupport::Concern

        # Track if we've already patched MessageDelivery
        @patched_message_delivery = false

        # We can't use included block with strict typing
        # This will be handled by ActiveSupport::Concern at runtime
        included do
          include ::ActiveSupport::Callbacks
          define_callbacks :deliver, skip_after_callbacks_if_terminated: true
        end

        # Define class methods in a separate module
        class_methods do
          extend T::Sig
          # Need to use T.unsafe for splat arguments due to Sorbet limitation
          # See: https://sorbet.org/docs/error-reference#7019

          # Defines a callback that will get called right before the
          # message is sent to the delivery method.
          sig { params(filters: T.untyped, blk: T.nilable(T.proc.bind(T.untyped).void)).void }
          def before_deliver(*filters, &blk)
            T.unsafe(self).set_callback(:deliver, :before, *filters, &blk)
          end

          # Defines a callback that will get called right after the
          # message's delivery method is finished.
          sig { params(filters: T.untyped, blk: T.nilable(T.proc.bind(T.untyped).void)).void }
          def after_deliver(*filters, &blk)
            T.unsafe(self).set_callback(:deliver, :after, *filters, &blk)
          end

          # Defines a callback that will get called around the message's deliver method.
          sig { params(filters: T.untyped, blk: T.nilable(T.proc.bind(T.untyped).params(arg0: T.untyped).void)).void }
          def around_deliver(*filters, &blk)
            T.unsafe(self).set_callback(:deliver, :around, *filters, &blk)
          end
        end

        sig { returns(T::Boolean) }
        def self.patch_message_delivery
          # Return early if we've already patched
          return true if @patched_message_delivery

          # Use T.unsafe only for the class_eval call since this is metaprogramming
          # that Sorbet can't statically analyze
          ::ActionMailer::MessageDelivery.class_eval do
            # Add handle_exceptions method if it doesn't exist
            unless method_defined?(:handle_exceptions)
              def handle_exceptions
                processed_mailer.handle_exceptions do
                  yield if block_given?
                end
              end
            end

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

          # Mark as patched so we don't do it again
          @patched_message_delivery = true
          true
        end
      end
    end
  end
end
