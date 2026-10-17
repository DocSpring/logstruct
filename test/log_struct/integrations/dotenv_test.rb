# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  module Integrations
    class DotenvTest < ActiveSupport::TestCase
      test "a problem with a Dotenv log line is a LogStruct error, so it doesn't stop the app in production" do
        # Subscribe again: other tests replace the notifier
        subscribed = Dotenv::STATE.subscribed
        listeners = ActiveSupport::Notifications.notifier.listeners_for("load.dotenv")
        Dotenv::STATE.subscribed = false
        Dotenv.subscribe!
        handled = []

        LogStruct.stub(:handle_exception, ->(error, source:, context:) { handled << [error.class, source, context] }) do
          # No env in the payload, so building the line fails
          ActiveSupport::Notifications.instrument("load.dotenv", env: nil)
        end

        refute_empty handled
        assert_equal [[NoMethodError, Source::Internal, {integration: :dotenv}]], handled.uniq
      ensure
        (ActiveSupport::Notifications.notifier.listeners_for("load.dotenv") - T.must(listeners)).each do |listener|
          ActiveSupport::Notifications.unsubscribe(listener)
        end
        Dotenv::STATE.subscribed = subscribed
      end
    end
  end
end
