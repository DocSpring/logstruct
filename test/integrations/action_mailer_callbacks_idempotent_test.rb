# typed: true
# frozen_string_literal: true

require "test_helper"

class ActionMailerCallbacksIdempotentTest < ActiveSupport::TestCase
  test "patch_message_delivery is idempotent" do
    assert LogStruct::Integrations::ActionMailer::Callbacks.patch_message_delivery
    # Calling again should be a no-op and still return true
    assert LogStruct::Integrations::ActionMailer::Callbacks.patch_message_delivery
  end
end
