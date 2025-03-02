# typed: false
# frozen_string_literal: true

require "spec_helper"

module RailsStructuredLogging::Integrations::ActionMailer
  RSpec.describe MetadataCollection do
    let(:message) { double("Mail::Message") }
    let(:mailer) { double("TestMailer", message: message, class: double("Class", name: "TestMailer")) }

    describe ".add_message_metadata" do
      context "when message is available" do
        before do
          allow(message).to receive_messages(
            to: ["test@example.com"],
            cc: nil,
            bcc: nil,
            attachments: [double("Attachment")]
          )
        end

        it "adds message metadata to log data" do
          log_data = {}
          RailsStructuredLogging::ActionMailer::MetadataCollection.add_message_metadata(mailer, log_data)

          expect(log_data[:recipient_count]).to eq(1)
          expect(log_data[:has_attachments]).to be(true)
          expect(log_data[:attachment_count]).to eq(1)
        end
      end

      context "when message is not available" do
        let(:mailer) { double("TestMailer", message: nil, class: double("Class", name: "TestMailer")) }

        it "adds default message metadata to log data" do
          log_data = {}
          RailsStructuredLogging::ActionMailer::MetadataCollection.add_message_metadata(mailer, log_data)

          expect(log_data[:recipient_count]).to eq(0)
          expect(log_data[:has_attachments]).to be(false)
          expect(log_data[:attachment_count]).to eq(0)
        end
      end
    end

    describe ".extract_ids_to_log_data" do
      context "when instance variables are defined" do
        let(:account) { double("Account", id: 123) }
        let(:user) { double("User", id: 456) }

        before do
          allow(mailer).to receive(:instance_variable_defined?).with(:@account).and_return(true)
          allow(mailer).to receive(:instance_variable_defined?).with(:@user).and_return(true)
          allow(mailer).to receive(:instance_variable_get).with(:@account).and_return(account)
          allow(mailer).to receive(:instance_variable_get).with(:@user).and_return(user)
        end

        it "extracts account and user IDs to log data" do
          log_data = {}
          RailsStructuredLogging::ActionMailer::MetadataCollection.extract_ids_to_log_data(mailer, log_data)

          expect(log_data[:account_id]).to eq(123)
          expect(log_data[:user_id]).to eq(456)
        end
      end

      context "when instance variables are not defined" do
        before do
          allow(mailer).to receive(:instance_variable_defined?).with(:@account).and_return(false)
          allow(mailer).to receive(:instance_variable_defined?).with(:@user).and_return(false)
        end

        it "handles missing instance variables gracefully" do
          log_data = {}
          RailsStructuredLogging::ActionMailer::MetadataCollection.extract_ids_to_log_data(mailer, log_data)

          expect(log_data).not_to have_key(:account_id)
          expect(log_data).not_to have_key(:user_id)
        end
      end
    end

    describe ".add_current_tags_to_log_data" do
      before do
        # Mock ActiveSupport::TaggedLogging
        stub_const("ActiveSupport::TaggedLogging", Class.new)
        allow(ActiveSupport::TaggedLogging).to receive(:respond_to?).with(:current_tags).and_return(true)
        allow(ActiveSupport::TaggedLogging).to receive(:current_tags).and_return(%w[tag1 tag2])

        # Mock ActionDispatch::Request
        stub_const("ActionDispatch", Module.new)
        stub_const("ActionDispatch::Request", Class.new)
        allow(ActionDispatch::Request).to receive(:respond_to?).with(:current_request_id).and_return(true)
        allow(ActionDispatch::Request).to receive(:current_request_id).and_return("request-123")

        # Mock ActiveJob::Logging
        stub_const("ActiveJob::Logging", Module.new)
        allow(ActiveJob::Logging).to receive(:respond_to?).with(:job_id).and_return(true)
        allow(ActiveJob::Logging).to receive(:job_id).and_return("job-456")
      end

      it "adds available tags to log data" do
        log_data = {}
        RailsStructuredLogging::ActionMailer::MetadataCollection.add_current_tags_to_log_data(log_data)

        expect(log_data[:tags]).to eq(%w[tag1 tag2])
        expect(log_data[:request_id]).to eq("request-123")
        expect(log_data[:job_id]).to eq("job-456")
      end
    end
  end
end
