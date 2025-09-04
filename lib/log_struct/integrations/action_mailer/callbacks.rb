# typed: strict
# frozen_string_literal: true

module LogStruct
  module Integrations
    module ActionMailer
      # Backport of the *_deliver callbacks from Rails 7.1
      module Callbacks
        extend T::Sig
        extend ::ActiveSupport::Concern

        # Track if we've already patched MessageDelivery
        @patched_message_delivery = T.let(false, T::Boolean)

        # We can't use included block with strict typing
        # This will be handled by ActiveSupport::Concern at runtime
        included do
          include ::ActiveSupport::Callbacks
          # Rails < 7.1 does not support skip_after_callbacks_if_terminated option
          if defined?(::ActiveSupport) && ::ActiveSupport.gem_version >= Gem::Version.new("7.1.0")
            define_callbacks :deliver, skip_after_callbacks_if_terminated: true
          else
            define_callbacks :deliver
          end
        end

        # Define class methods in a separate module
        module ClassMethods
          extend T::Sig

          # Defines a callback that will get called right before the
          # message is sent to the delivery method.
          sig { params(filters: T.untyped, blk: T.nilable(T.proc.bind(T.untyped).void)).void }
          def before_deliver(*filters, &blk)
            # Use T.unsafe for splat arguments due to Sorbet limitation
            T.unsafe(self).set_callback(:deliver, :before, *filters, &blk)
          end

          # Defines a callback that will get called right after the
          # message's delivery method is finished.
          sig { params(filters: T.untyped, blk: T.nilable(T.proc.bind(T.untyped).void)).void }
          def after_deliver(*filters, &blk)
            # Use T.unsafe for splat arguments due to Sorbet limitation
            T.unsafe(self).set_callback(:deliver, :after, *filters, &blk)
          end

          # Defines a callback that will get called around the message's deliver method.
          sig { params(filters: T.untyped, blk: T.nilable(T.proc.bind(T.untyped).params(arg0: T.untyped).void)).void }
          def around_deliver(*filters, &blk)
            # Use T.unsafe for splat arguments due to Sorbet limitation
            T.unsafe(self).set_callback(:deliver, :around, *filters, &blk)
          end
        end

        # Module to patch ActionMailer::MessageDelivery with callback support
        module MessageDeliveryCallbacks
          extend T::Sig

          sig { returns(T.untyped) }
          def deliver_now
            processed_mailer.run_callbacks(:deliver) do
              message.deliver
            end
          end

          sig { returns(T.untyped) }
          def deliver_now!
            processed_mailer.run_callbacks(:deliver) do
              message.deliver!
            end
          end
        end

        sig { returns(T::Boolean) }
        def self.patch_message_delivery
          # Return early if we've already patched
          return true if @patched_message_delivery

          # Prepend our module to add callback support to MessageDelivery
          ::ActionMailer::MessageDelivery.prepend(MessageDeliveryCallbacks)

          # Mark as patched so we don't do it again
          @patched_message_delivery = true
          true
        end
      end
    end
  end
end
