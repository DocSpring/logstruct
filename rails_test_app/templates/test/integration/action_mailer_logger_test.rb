# typed: true
# frozen_string_literal: true

require "test_helper"

class ActionMailerLoggerTest < ActiveSupport::TestCase
  test "mailers log with LogStruct's logger, and Rails' own mail log lines are replaced" do
    assert_same Rails.logger, ActionMailer::Base.logger
    assert_kind_of LogStruct::SemanticLogger::Logger, ActionMailer::Base.logger

    rails_mail_subscribers = ActiveSupport::LogSubscriber.log_subscribers.select do |subscriber|
      subscriber.is_a?(ActionMailer::LogSubscriber)
    end

    assert_empty rails_mail_subscribers
  end
end
