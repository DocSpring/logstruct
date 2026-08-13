# typed: true

require "simplecov" unless defined?(SimpleCov)
require "simplecov-json"
require "sorbet-runtime"
require "debug"
require "open3"
require "timeout"

# SimpleCov >= 1.0 replaced the `running` accessor with `active_session?`
simplecov_started =
  if SimpleCov.respond_to?(:active_session?)
    SimpleCov.active_session?
  else
    SimpleCov.running
  end

unless simplecov_started
  SimpleCov.formatters = [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::JSONFormatter
  ]

  SimpleCov.start do
    T.bind(self, T.all(SimpleCov::Configuration, Kernel))

    gem_path = File.expand_path("../../../../", __FILE__)
    SimpleCov.root(gem_path)

    # SimpleCov >= 1.0 deprecated `add_filter` in favor of `skip`
    if SimpleCov.respond_to?(:skip)
      SimpleCov.skip "rails_test_app"
    else
      SimpleCov.add_filter "rails_test_app"
    end

    coverage_dir "coverage_rails"

    enable_coverage :branch
    primary_coverage :branch
  end

  SimpleCov.at_exit do
    SimpleCov.result
  end
end

# Require logstruct after starting SimpleCov
require "logstruct"

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/reporters"

# Configure colorful test output
Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

# Avoid hangs by enforcing per-test timeouts in the Rails test app
module LogStructMinitestTimeout
  def run
    timeout_seconds = ENV.fetch("LOGSTRUCT_TEST_TIMEOUT", "60").to_i
    return super if timeout_seconds <= 0

    Timeout.timeout(timeout_seconds) { super }
  rescue Timeout::Error
    self.fail("Test timed out after #{timeout_seconds}s")
  end
end

Minitest::Test.prepend(LogStructMinitestTimeout)

# Configure the test database
class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  # fixtures :all

  # Add more helper methods to be used by all tests here...

  # Helper method to run jobs synchronously
  def perform_enqueued_jobs
    jobs = ActiveJob::Base.queue_adapter.enqueued_jobs
    jobs.each do |job|
      ActiveJob::Base.execute job
    end
  end
end

module LogStructTestHelpers
  def with_process(env:, cmd:, ready_timeout: 15, ready_matchers: [])
    lines = []
    err_lines = []

    Open3.popen3(env, *cmd) do |stdin, stdout, stderr, wait_thr|
      stdin.close
      begin
        wait_for_ready(stdout, lines, ready_timeout, ready_matchers)
        yield(lines, stdout, stderr, wait_thr)
      rescue Timeout::Error => e
        drain_stream(stderr, err_lines, timeout: 2)
        raise Timeout::Error, "#{e.message}\nOutput: #{lines.join("\n")}\nSTDERR: #{err_lines.join("\n")}"
      ensure
        terminate_process(wait_thr, timeout: 10)
        drain_stream(stdout, lines, timeout: 5)
        drain_stream(stderr, err_lines, timeout: 5)
      end
    end

    [lines, err_lines.join("\n")]
  end

  def drain_nonblocking(io, lines)
    loop do
      chunk = io.read_nonblock(4096)
      lines.concat(chunk.split("\n").map(&:strip))
    rescue IO::WaitReadable, EOFError
      break
    end
  end

  def rails_server_env(logstruct_enabled: true, rails_env: "test")
    {
      "LOGSTRUCT_ENABLED" => logstruct_enabled ? "true" : "false",
      "RAILS_ENV" => rails_env,
      "RAILS_LOG_TO_STDOUT" => "1"
    }
  end

  def rails_server_cmd(port)
    ["bundle", "exec", "rails", "server", "-p", port.to_s]
  end

  private

  def wait_for_ready(stdout, lines, timeout_seconds, ready_matchers)
    Timeout.timeout(timeout_seconds) do
      while (line = stdout.gets)
        stripped = line.strip
        lines << stripped
        break if ready_matchers.any? { |matcher| matcher === stripped || stripped.include?(matcher.to_s) }
      end
    end
  end

  def drain_stream(io, lines, timeout:)
    Timeout.timeout(timeout) do
      while (line = io.gets)
        lines << line.strip
      end
    end
  rescue Timeout::Error
    nil
  end

  def terminate_process(wait_thr, timeout:)
    Process.kill("TERM", wait_thr.pid)
    begin
      Timeout.timeout(timeout) { wait_thr.value }
    rescue Timeout::Error
      begin
        Process.kill("KILL", wait_thr.pid)
      rescue Errno::ESRCH
        nil
      end
    end
  rescue Errno::ESRCH
    nil
  end
end

ActiveSupport::TestCase.include(LogStructTestHelpers)

# Ensure LogStruct is enabled and emits JSON in tests across Rails versions
begin
  LogStruct.configure do |config|
    config.enabled = true
    # Prefer production-style JSON in development/test
    config.prefer_json_in_development = true
  end
rescue NameError
  # LogStruct not loaded; ignore
end
