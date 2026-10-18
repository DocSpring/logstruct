# typed: true
# frozen_string_literal: true

require "test_helper"
require "action_mailer"

class ActionMailerMetadataCollectionTest < ActiveSupport::TestCase
  MetadataCollection = LogStruct::Integrations::ActionMailer::MetadataCollection

  DummyMessage = Struct.new(:to, :cc, :bcc, :attachments, :subject, :from, :message_id)

  test "add_message_metadata counts attachments when message present" do
    msg = DummyMessage.new(%w[a@b.com], nil, %w[x@y.com], [1, 2], "S", ["from@example.com"], "mid")
    data = {}
    MetadataCollection.add_message_metadata(OpenStruct.new(message: msg), data)

    assert_equal 2, data[:attachment_count]
  end

  test "add_message_metadata sets defaults when message missing" do
    data = {}
    MetadataCollection.add_message_metadata(OpenStruct.new, data)

    assert_equal 0, data[:attachment_count]
  end
end
