# typed: strong

module LogStruct::Integrations::ActionMailer::Callbacks::MessageDeliveryCallbacks
  # Tell Sorbet that we are prepending this module into ActionMailer::MessageDelivery
  requires_ancestor { ::ActionMailer::MessageDelivery }
end
