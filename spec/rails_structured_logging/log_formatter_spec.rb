# frozen_string_literal: true

require_relative '../spec_helper'
require 'rails_structured_logging/log_formatter'
require 'rails_structured_logging/multi_error_reporter'

RSpec.describe RailsStructuredLogging::LogFormatter do
  subject(:formatter) { described_class.new }

  let(:severity) { 'INFO' }
  let(:time) { Time.utc(2023, 1, 1, 12, 0, 0) }
  let(:progname) { 'test' }
  let(:iso_time) { '2023-01-01T12:00:00.000Z' }

  # Clean up after tests
  after(:each) do
    Thread.current[:activesupport_tagged_logging_tags] = nil
  end

  describe '#call' do
    context 'with a string message' do
      let(:message) { 'Test message' }

      it 'wraps the string in a hash with msg key' do
        result = JSON.parse(formatter.call(severity, time, progname, message))
        expect(result['msg']).to eq(message)
      end

      it 'adds standard fields' do
        result = JSON.parse(formatter.call(severity, time, progname, message))
        expect(result['src']).to eq('rails')
        expect(result['evt']).to eq('log')
        expect(result['ts']).to eq(iso_time)
        expect(result['level']).to eq('info')
        expect(result['progname']).to eq(progname)
      end

      it 'applies LogstopFork scrubbing to the message' do
        # Use real LogstopFork scrubbing
        allow(RailsStructuredLogging::LogstopFork).to receive(:scrub).and_call_original
        email_message = 'Email: user@example.com'
        result = JSON.parse(formatter.call(severity, time, progname, email_message))
        expect(result['msg']).not_to include('user@example.com')
        expect(RailsStructuredLogging::LogstopFork).to have_received(:scrub).at_least(:once)
      end
    end

    context 'with a hash message' do
      let(:message) { { custom_field: 'value', msg: 'Test message' } }

      it 'preserves the hash structure' do
        result = JSON.parse(formatter.call(severity, time, progname, message))
        expect(result['custom_field']).to eq('value')
        expect(result['msg']).to eq('Test message')
      end

      it 'adds standard fields if not present' do
        result = JSON.parse(formatter.call(severity, time, progname, message))
        expect(result['src']).to eq('rails')
        expect(result['evt']).to eq('log')
        expect(result['ts']).to eq(iso_time)
        expect(result['level']).to eq('info')
      end

      it 'does not override existing fields' do
        custom_message = { src: 'custom', evt: 'test_event', ts: 'custom_time' }
        result = JSON.parse(formatter.call(severity, time, progname, custom_message))
        expect(result['src']).to eq('custom')
        expect(result['evt']).to eq('test_event')
        expect(result['ts']).to eq('custom_time')
      end

      it 'applies LogstopFork scrubbing to string message fields' do
        allow(RailsStructuredLogging::LogstopFork).to receive(:scrub).and_call_original
        email_message = { msg: 'Email: user@example.com' }
        result = JSON.parse(formatter.call(severity, time, progname, email_message))
        expect(result['msg']).not_to include('user@example.com')
        expect(RailsStructuredLogging::LogstopFork).to have_received(:scrub).at_least(:once)
      end
    end

    context 'with ActiveJob logs' do
      let(:user_class) do
        Class.new do
          include GlobalID::Identification
          attr_accessor :id

          def initialize(id)
            @id = id
          end

          def to_global_id
            GlobalID.new("gid://rails-structured-logging/User/#{id}")
          end

          def self.name
            'User'
          end
        end
      end

      let(:user) { user_class.new(123) }

      it 'formats ActiveJob arguments with GlobalIDs' do
        message = {
          src: 'active_job',
          arguments: [user, { email: 'test@example.com' }],
        }

        result = JSON.parse(formatter.call(severity, time, progname, message))
        expect(result['arguments'][0]).to eq('gid://rails-structured-logging/User/123')
        expect(result['arguments'][1]['email']).not_to include('test@example.com')
      end

      it 'handles GlobalID errors gracefully' do
        broken_user = user_class.new(456)
        allow(broken_user).to receive(:to_global_id).and_raise(StandardError.new("Can't serialize"))

        # The second error is what triggers MultiErrorReporter
        allow(broken_user).to receive(:id).and_raise(StandardError.new("Can't get ID"))
        allow(RailsStructuredLogging::MultiErrorReporter).to receive(:report_exception)

        message = {
          src: 'active_job',
          arguments: [broken_user],
        }

        result = JSON.parse(formatter.call(severity, time, progname, message))
        expect(result['arguments'][0]).to eq('[GlobalID Error]')
        expect(RailsStructuredLogging::MultiErrorReporter).to have_received(:report_exception)
      end
    end
  end

  describe 'tagged logging support' do
    before(:each) do
      # Ensure tags are cleared before each test
      Thread.current[:activesupport_tagged_logging_tags] = nil
    end

    it 'supports current_tags' do
      expect(formatter.current_tags).to eq([])
      Thread.current[:activesupport_tagged_logging_tags] = %w[tag1 tag2]
      expect(formatter.current_tags).to eq(%w[tag1 tag2])
    end

    it 'supports tagged method' do
      result = nil
      formatter.tagged('tag1', 'tag2') do |f|
        expect(f.current_tags).to eq(%w[tag1 tag2])
        result = f
      end
      expect(formatter.current_tags).to eq([])
      expect(result).to eq(formatter)
    end

    it 'supports clear_tags!' do
      Thread.current[:activesupport_tagged_logging_tags] = %w[tag1 tag2]
      formatter.clear_tags!
      expect(formatter.current_tags).to eq([])
    end
  end

  describe '#format_values' do
    let(:user_class) do
      Class.new do
        include GlobalID::Identification
        attr_accessor :id

        def initialize(id)
          @id = id
        end

        def to_global_id
          GlobalID.new("gid://rails-structured-logging/User/#{id}")
        end

        def self.name
          'User'
        end
      end
    end

    let(:user) { user_class.new(123) }

    it 'formats GlobalID::Identification objects as GlobalIDs' do
      expect(formatter.format_values(user)).to eq('gid://rails-structured-logging/User/123')
    end

    it 'formats hashes recursively' do
      arg = { user: user, data: { value: 'test' } }
      result = formatter.format_values(arg)
      expect(result[:user]).to eq('gid://rails-structured-logging/User/123')
      expect(result[:data][:value]).to eq('test')
    end

    it 'formats arrays recursively' do
      arg = [user, { email: 'test@example.com' }]
      result = formatter.format_values(arg)
      expect(result[0]).to eq('gid://rails-structured-logging/User/123')
      expect(result[1][:email]).not_to include('test@example.com')
    end

    it 'truncates large arrays' do
      arg = (1..20).to_a
      result = formatter.format_values(arg)
      expect(result.length).to eq(11)
      expect(result.last).to eq('... and 10 more items')
    end

    it 'handles recursive structures without infinite recursion' do
      hash1 = { a: 1 }
      hash2 = { b: 2, hash1: hash1 }
      hash1[:hash2] = hash2  # Create a circular reference

      # This should not cause an infinite recursion
      result = formatter.format_values(hash1)
      expect(result).to be_a(Hash)
      expect(result[:a]).to eq(1)
      expect(result[:hash2][:b]).to eq(2)
    end
  end

  describe '#generate_json' do
    it 'converts data to JSON with a newline' do
      data = { key: 'value' }
      expect(formatter.generate_json(data)).to eq("{\"key\":\"value\"}\n")
    end
  end
end
