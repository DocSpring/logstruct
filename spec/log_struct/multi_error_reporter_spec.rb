# typed: strict
# frozen_string_literal: true

require "spec_helper"

module LogStruct
  RSpec.describe MultiErrorReporter do
    T.bind(self, T.class_of(RSpec::ExampleGroups::LogStructMultiErrorReporter))
    extend RSpec::Sorbet::Types::Sig

    rsig { returns(StandardError) }
    let(:exception) { StandardError.new("Test error") }

    rsig { returns(T::Hash[T.untyped, T.untyped]) }
    let(:context) { {user_id: 123, action: "test"} }

    before do
      # Reset the error reporter before each test
      MultiErrorReporter.instance_variable_set(:@error_reporter, nil)

      # Stub stdout to capture output
      allow($stdout).to receive(:puts)
    end

    describe ".report_exception" do
      context "with disabled reporters" do
        T.bind(self, T.class_of(RSpec::ExampleGroups::LogStructMultiErrorReporter::ReportException::WithDisabledReporters))
        rsig { returns(T.nilable(ErrorReporter)) }
        let(:reporter) { nil }

        before do
          # Hide all error reporting services by default
          hide_const("Sentry") if reporter != :sentry && reporter != :all
          hide_const("Bugsnag") if reporter != :bugsnag && reporter != :all
          hide_const("Rollbar") if reporter != :rollbar && reporter != :all
          hide_const("Honeybadger") if reporter != :honeybadger && reporter != :all
        end

        context "when Sentry is available" do
          let(:reporter) { ErrorReporter::Sentry }

          before do
            allow(Sentry).to receive(:capture_exception)
          end

          it "reports the exception to Sentry" do
            expect(Sentry).to receive(:capture_exception).with(exception, extra: context)
            MultiErrorReporter.report_exception(exception, context)
          end

          it "initializes the reporter to use Sentry" do
            MultiErrorReporter.report_exception(exception, context)
            expect(MultiErrorReporter.error_reporter).to eq(
              ErrorReporter::Sentry
            )
          end

          context "when Sentry raises an error" do
            before do
              allow(Sentry).to receive(:capture_exception).and_raise(RuntimeError.new("Sentry error"))
            end

            it "falls back to stdout logging" do
              expect($stdout).to receive(:puts).with(kind_of(String))
              MultiErrorReporter.report_exception(exception, context)
            end
          end
        end

        context "when Bugsnag is available" do
          T.bind(self, T.class_of(RSpec::ExampleGroups::LogStructMultiErrorReporter::ReportException::WithDisabledReporters::WhenBugsnagIsAvailable))

          let(:reporter) { ErrorReporter::Bugsnag }

          rsig { returns(T.nilable(RSpec::Mocks::Double)) }
          let(:report) { double("report") }

          before do
            allow(Bugsnag).to receive(:notify).and_yield(report)
            allow(report).to receive(:add_metadata)
          end

          it "reports the exception to Bugsnag" do
            expect(Bugsnag).to receive(:notify).with(exception)
            expect(report).to receive(:add_metadata).with(:context, context)
            MultiErrorReporter.report_exception(exception, context)
          end

          it "initializes the reporter to use Bugsnag" do
            MultiErrorReporter.report_exception(exception, context)
            expect(MultiErrorReporter.error_reporter).to eq(
              ErrorReporter::Bugsnag
            )
          end
        end

        context "when Rollbar is available" do
          let(:reporter) { ErrorReporter::Rollbar }

          before do
            allow(Rollbar).to receive(:error)
          end

          it "reports the exception to Rollbar" do
            expect(Rollbar).to receive(:error).with(exception, context)
            MultiErrorReporter.report_exception(exception, context)
          end

          it "initializes the reporter to use Rollbar" do
            MultiErrorReporter.report_exception(exception, context)
            expect(MultiErrorReporter.error_reporter).to eq(
              ErrorReporter::Rollbar
            )
          end
        end

        context "when Honeybadger is available" do
          let(:reporter) { ErrorReporter::Honeybadger }

          before do
            allow(Honeybadger).to receive(:notify)
          end

          it "reports the exception to Honeybadger" do
            expect(Honeybadger).to receive(:notify).with(exception, context: context)
            MultiErrorReporter.report_exception(exception, context)
          end

          it "initializes the reporter to use Honeybadger" do
            MultiErrorReporter.report_exception(exception, context)
            expect(MultiErrorReporter.error_reporter).to eq(
              ErrorReporter::Honeybadger
            )
          end
        end

        context "when no error reporting service is available" do
          let(:reporter) { nil }

          it "logs to stdout with structured JSON" do
            json_output = T.let(nil, T.nilable(String))
            expect($stdout).to receive(:puts) do |output|
              json_output = output
            end

            MultiErrorReporter.report_exception(exception, context)

            parsed_output = JSON.parse(json_output || "", symbolize_names: true)
            expect(parsed_output[:src]).to eq("rails")
            expect(parsed_output[:evt]).to eq("error")
            expect(parsed_output[:error_class]).to eq("StandardError")
            expect(parsed_output[:error_message]).to eq("Test error")
            expect(parsed_output[:context]).to eq(context)
          end

          it "initializes the reporter to use fallback" do
            MultiErrorReporter.report_exception(exception, context)
            expect(MultiErrorReporter.error_reporter).to eq(:fallback)
          end
        end
      end

      context "with all available reporters" do
        before do
          allow(Sentry).to receive(:capture_exception)
          allow(Bugsnag).to receive(:notify)
          allow(Rollbar).to receive(:error)
          allow(Honeybadger).to receive(:notify)
        end

        it "uses the first available service (Sentry)" do
          expect(Sentry).to receive(:capture_exception)
          expect(Bugsnag).not_to receive(:notify)
          expect(Rollbar).not_to receive(:error)
          expect(Honeybadger).not_to receive(:notify)

          MultiErrorReporter.report_exception(exception, context)
        end
      end
    end
  end
end
