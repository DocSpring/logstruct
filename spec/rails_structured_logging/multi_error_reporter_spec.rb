# frozen_string_literal: true

require 'spec_helper'
require 'rails_structured_logging/multi_error_reporter'

RSpec.describe RailsStructuredLogging::MultiErrorReporter do
  let(:exception) { StandardError.new("Test error") }
  let(:context) { { user_id: 123, action: "test" } }

  describe '.report_exception' do
    before do
      # Reset the error reporter before each test
      described_class.instance_variable_set(:@error_reporter, nil)
      # Stub stdout to capture output
      allow($stdout).to receive(:puts)
    end

    context 'when Sentry is available' do
      before do
        stub_const('Sentry', double)
        allow(Sentry).to receive(:capture_exception)
      end

      it 'reports the exception to Sentry' do
        expect(Sentry).to receive(:capture_exception).with(exception, extra: context)
        described_class.report_exception(exception, context)
      end

      it 'initializes the reporter to use Sentry' do
        described_class.report_exception(exception, context)
        expect(described_class.error_reporter).to eq(:sentry)
      end

      context 'when Sentry raises an error' do
        before do
          allow(Sentry).to receive(:capture_exception).and_raise(RuntimeError.new("Sentry error"))
        end

        it 'falls back to stdout logging' do
          expect($stdout).to receive(:puts).with(kind_of(String))
          described_class.report_exception(exception, context)
        end
      end
    end

    context 'when Bugsnag is available' do
      let(:report) { double }

      before do
        stub_const('Bugsnag', double)
        allow(Bugsnag).to receive(:notify).and_yield(report)
        allow(report).to receive(:add_metadata)
      end

      it 'reports the exception to Bugsnag' do
        expect(Bugsnag).to receive(:notify).with(exception)
        expect(report).to receive(:add_metadata).with(:context, context)
        described_class.report_exception(exception, context)
      end

      it 'initializes the reporter to use Bugsnag' do
        described_class.report_exception(exception, context)
        expect(described_class.error_reporter).to eq(:bugsnag)
      end
    end

    context 'when Rollbar is available' do
      before do
        stub_const('Rollbar', double)
        allow(Rollbar).to receive(:error)
      end

      it 'reports the exception to Rollbar' do
        expect(Rollbar).to receive(:error).with(exception, context)
        described_class.report_exception(exception, context)
      end

      it 'initializes the reporter to use Rollbar' do
        described_class.report_exception(exception, context)
        expect(described_class.error_reporter).to eq(:rollbar)
      end
    end

    context 'when Honeybadger is available' do
      before do
        stub_const('Honeybadger', double)
        allow(Honeybadger).to receive(:notify)
      end

      it 'reports the exception to Honeybadger' do
        expect(Honeybadger).to receive(:notify).with(exception, context: context)
        described_class.report_exception(exception, context)
      end

      it 'initializes the reporter to use Honeybadger' do
        described_class.report_exception(exception, context)
        expect(described_class.error_reporter).to eq(:honeybadger)
      end
    end

    context 'when no error reporting service is available' do
      it 'logs to stdout with structured JSON' do
        json_output = nil
        expect($stdout).to receive(:puts) do |output|
          json_output = output
        end

        described_class.report_exception(exception, context)

        parsed_output = JSON.parse(json_output, symbolize_names: true)
        expect(parsed_output[:src]).to eq('rails')
        expect(parsed_output[:evt]).to eq('error')
        expect(parsed_output[:error_class]).to eq('StandardError')
        expect(parsed_output[:error_message]).to eq('Test error')
        expect(parsed_output[:context]).to eq(context)
      end

      it 'initializes the reporter to use fallback' do
        described_class.report_exception(exception, context)
        expect(described_class.error_reporter).to eq(:fallback)
      end
    end

    context 'when exception is nil' do
      it 'does nothing' do
        expect(Sentry).not_to receive(:capture_exception) if defined?(Sentry)
        expect($stdout).not_to receive(:puts)
        described_class.report_exception(nil)
      end
    end

    context 'with multiple error services available' do
      before do
        # Define all services but only Sentry should be used (first one)
        stub_const('Sentry', double)
        stub_const('Bugsnag', double)
        stub_const('Rollbar', double)
        stub_const('Honeybadger', double)

        allow(Sentry).to receive(:capture_exception)
        allow(Bugsnag).to receive(:notify)
        allow(Rollbar).to receive(:error)
        allow(Honeybadger).to receive(:notify)
      end

      it 'uses the first available service (Sentry)' do
        expect(Sentry).to receive(:capture_exception)
        expect(Bugsnag).not_to receive(:notify)
        expect(Rollbar).not_to receive(:error)
        expect(Honeybadger).not_to receive(:notify)

        described_class.report_exception(exception, context)
      end
    end
  end
end
