# typed: true

require "test_helper"
require "open3"
require "timeout"
require "net/http"

class RequestLoggingE2eTest < ActiveSupport::TestCase
  # Test that real HTTP requests through Puma produce valid JSON request logs
  def test_real_http_request_produces_json_request_log
    port = 32125
    env = {
      "LOGSTRUCT_ENABLED" => "true",
      "RAILS_ENV" => "test",
      "RAILS_LOG_TO_STDOUT" => "1"
    }

    cmd = ["bundle", "exec", "rails", "server", "-p", port.to_s]

    Open3.popen3(env, *cmd) do |_stdin, stdout, stderr, wait_thr|
      lines = []
      begin
        # Wait for server to be ready
        Timeout.timeout(15) do
          while (line = stdout.gets)
            lines << line.strip
            break if line.include?("Use Ctrl-C to stop") || line.include?("Listening on")
          end
        end

        # Make a real HTTP request to a controller action (not proc) to trigger Lograge
        uri = URI("http://127.0.0.1:#{port}/logging/basic")
        response = Net::HTTP.get_response(uri)

        assert_equal "200", response.code, "Request should succeed"

        # Give logs time to flush
        sleep 0.5

        # Collect any additional output non-blocking
        loop do
          line = stdout.read_nonblock(4096)
          lines.concat(line.split("\n").map(&:strip))
        rescue IO::WaitReadable, EOFError
          break
        end
      rescue Timeout::Error
        flunk "Server did not start in time. Output: #{lines.join("\n")}\nSTDERR: #{stderr.read}"
      ensure
        begin
          Process.kill("TERM", wait_thr.pid)
        rescue Errno::ESRCH
          # already dead
        end

        # Collect shutdown output
        begin
          Timeout.timeout(5) do
            while (line = stdout.gets)
              lines << line.strip
            end
          end
        rescue Timeout::Error
          # ignore
        end
      end

      output = lines.join("\n")
      stderr_output = stderr.read

      # Parse all JSON log lines
      json_lines = lines.filter_map do |l|
        JSON.parse(l) if l.strip.start_with?("{")
      rescue JSON::ParserError
        nil
      end

      # Find request logs (Lograge output has evt:"request")
      request_logs = json_lines.select { |h| h["evt"] == "request" }

      assert_predicate request_logs,
        :any?,
        "Expected at least one request log.\nJSON logs: #{json_lines.map(&:inspect).join("\n")}\nAll output: #{output}\nSTDERR: #{stderr_output}"

      request_log = request_logs.first

      # Verify it's valid JSON with proper LogStruct fields
      assert_equal "rails", request_log["src"], "Source must be 'rails'"
      assert_equal "request", request_log["evt"], "Event must be 'request'"
      assert request_log.key?("path"), "Must have 'path' field"
      assert request_log.key?("status"), "Must have 'status' field"
      assert request_log.key?("duration_ms"), "Must have 'duration_ms' field"

      # MUST NOT be Ruby hash inspect format
      request_line = lines.find { |l| l.include?('"evt":"request"') }

      assert request_line, "Should find request log line"
      refute_match(/\{message:/, request_line, "Request log must NOT be Ruby hash inspect format")
      refute_match(/\{:message=>/, request_line, "Request log must NOT be Ruby hash rocket format")
    end
  end

  # Test that AMS-style tagged logging doesn't produce broken format
  def test_tagged_logging_does_not_produce_ruby_hash_format
    port = 32126
    env = {
      "LOGSTRUCT_ENABLED" => "true",
      "RAILS_ENV" => "test",
      "RAILS_LOG_TO_STDOUT" => "1"
    }

    cmd = ["bundle", "exec", "rails", "server", "-p", port.to_s]

    Open3.popen3(env, *cmd) do |_stdin, stdout, stderr, wait_thr|
      lines = []
      begin
        # Wait for server to be ready
        Timeout.timeout(15) do
          while (line = stdout.gets)
            lines << line.strip
            break if line.include?("Use Ctrl-C to stop") || line.include?("Listening on")
          end
        end

        # Make a real HTTP request to a controller action to trigger logging
        uri = URI("http://127.0.0.1:#{port}/logging/basic")
        Net::HTTP.get_response(uri)

        # Give logs time to flush
        sleep 0.5

        # Collect any additional output non-blocking
        loop do
          line = stdout.read_nonblock(4096)
          lines.concat(line.split("\n").map(&:strip))
        rescue IO::WaitReadable, EOFError
          break
        end
      rescue Timeout::Error
        flunk "Server did not start in time. Output: #{lines.join("\n")}\nSTDERR: #{stderr.read}"
      ensure
        begin
          Process.kill("TERM", wait_thr.pid)
        rescue Errno::ESRCH
          # already dead
        end

        begin
          Timeout.timeout(5) do
            while (line = stdout.gets)
              lines << line.strip
            end
          end
        rescue Timeout::Error
          # ignore
        end
      end

      # NO line should have the broken [tag] {message: ...} format
      lines.each do |line|
        refute_match(
          /\[[\w_]+\]\s*\{message:/,
          line,
          "No log line should have broken [tag] {message: ...} format. Line: #{line}"
        )
        refute_match(
          /\{message:.*tags:/,
          line,
          "No log line should have {message: ..., tags: ...} Ruby format. Line: #{line}"
        )
      end

      # All JSON lines should be valid JSON (not Ruby hash inspect)
      json_lines = lines.select { |l| l.strip.start_with?("{") }
      json_lines.each do |line|
        parsed = JSON.parse(line)

        assert parsed, "Line should be valid JSON: #{line}"
      rescue JSON::ParserError => e
        flunk "Line should be valid JSON but got parse error: #{e.message}\nLine: #{line}"
      end
    end
  end
end
