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

  test "add_context_metadata gathers tags when available" do
    data = {}

    # Stub ActiveSupport::TaggedLogging.current_tags
    ActiveSupport::TaggedLogging.define_singleton_method(:current_tags) { ["req:abc"] }

    MetadataCollection.add_context_metadata(Object.new, data)

    assert_equal ["req:abc"], data[:tags]
    # Note: request_id is now handled centrally by serialize_common via LogStruct::Current
  end

  test "add_context_metadata includes job_id when ActiveJob::Logging.job_id is available" do
    data = {}
    # Ensure module exists
    unless defined?(::ActiveJob::Logging)
      module ::ActiveJob
        module Logging; end
      end
    end
    # Define job_id method on the module's singleton class
    ::ActiveJob::Logging.define_singleton_method(:job_id) { "jid-1" }
    MetadataCollection.add_context_metadata(Object.new, data)

    assert_equal "jid-1", data[:job_id]
  end
end
