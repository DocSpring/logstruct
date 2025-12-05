# typed: true

require "test_helper"
require "open3"
require "timeout"

class PumaIntegrationTest < ActiveSupport::TestCase
  # Test that running `puma` directly (without `rails server`) auto-enables LogStruct
  # via Puma::Server detection - no LOGSTRUCT_ENABLED env var needed
  def test_puma_direct_auto_enables_logstruct
    port = 32124
    env = {
      "RAILS_ENV" => "production",
      "RAILS_LOG_TO_STDOUT" => "1",
      "SECRET_KEY_BASE" => "test_secret_key_base_for_production_mode_1234567890"
    }

    # Run puma directly, NOT rails server
    cmd = ["bundle", "exec", "puma", "-p", port.to_s, "-e", "production"]

    Open3.popen3(env, *cmd) do |_stdin, stdout, stderr, wait_thr|
      begin
        lines = []
        Timeout.timeout(15) do
          while (line = stdout.gets)
            lines << line.strip
            # Puma outputs "Listening on" when ready
            break if line.include?("Listening on")
          end
        end

        # Send TERM to trigger graceful shutdown
        begin
          Process.kill("TERM", wait_thr.pid)
        rescue Errno::ESRCH
          # Process already exited
        end

        # Collect shutdown output
        Timeout.timeout(10) do
          while (line = stdout.gets)
            lines << line.strip
          end
        end
      rescue Timeout::Error
        # Fall through and ensure process is terminated
      ensure
        begin
          Process.kill("TERM", wait_thr.pid)
        rescue Errno::ESRCH
          # already dead
        end
      end

      output = lines.join("\n")
      stderr_output = stderr.read

      # Find JSON log lines - LogStruct should be enabled via Puma::Server detection
      json_lines = lines.filter_map do |l|
        JSON.parse(l) if l.strip.start_with?("{")
      rescue JSON::ParserError
        nil
      end

      assert_predicate json_lines,
        :any?,
        "Expected JSON logs from direct puma invocation (Puma::Server detection should enable LogStruct).\n" \
        "STDOUT: #{output}\nSTDERR: #{stderr_output}"

      # Verify we got puma lifecycle logs
      puma_logs = json_lines.select { |h| h["src"] == "puma" }

      assert_predicate puma_logs,
        :any?,
        "Expected puma lifecycle logs. JSON logs: #{json_lines.inspect}"
    end
  end

  def test_rails_server_emits_structured_puma_logs_and_on_exit
    port = 32123
    env = {
      "LOGSTRUCT_ENABLED" => "true",
      "RAILS_ENV" => "test",
      "RAILS_LOG_TO_STDOUT" => "1"
    }

    cmd = ["bundle", "exec", "rails", "server", "-p", port.to_s]

    Open3.popen3(env, *cmd) do |_stdin, stdout, stderr, wait_thr| # cspell:disable-line
      begin
        lines = []
        Timeout.timeout(10) do
          while (line = stdout.gets)
            lines << line.strip
            break if line.include?("Use Ctrl-C to stop")
          end
        end

        # Send TERM to trigger graceful shutdown
        begin
          Process.kill("TERM", wait_thr.pid)
        rescue Errno::ESRCH
          # Process already exited
        end

        # Collect shutdown output
        Timeout.timeout(10) do
          while (line = stdout.gets)
            lines << line.strip
          end
        end
      rescue Timeout::Error
        # Fall through and ensure process is terminated
      ensure
        begin
          Process.kill("TERM", wait_thr.pid)
        rescue Errno::ESRCH
          # already dead
        end
      end

      output = lines.join("\n")
      lines.filter_map { |l|
        begin
          JSON.parse(l)
        rescue
          nil
        end
      }
      # Consider only logs after the first JSON line
      first_json_index = lines.find_index { |l|
        l.strip.start_with?("{") && begin
          JSON.parse(l)
        rescue
          nil
        end
      }

      assert first_json_index, "Did not find any JSON log lines. Output: #{output}\nSTDERR: #{stderr.read}"
      after_lines = lines[first_json_index..]
      after_json = after_lines.filter_map do |l|
        JSON.parse(l)
      rescue JSON::ParserError
        nil
      end
      puma_logs = after_json.select { |h| h["src"] == "puma" }

      # Expect exactly 2 structured logs: start, shutdown
      assert_equal 2, puma_logs.length, "Expected exactly 2 Puma logs. Output: #{output}\nSTDERR: #{stderr.read}"

      events = puma_logs.map { |h| h["evt"] }

      assert_equal ["start", "shutdown"], events, "Expected Puma events in order: start, shutdown"

      start = puma_logs[0]

      assert_equal "puma", start["src"]
      assert_equal "info", start["lvl"]
      assert_equal "single", start["mode"]
      assert_equal "test", start["environment"]
      assert_kind_of Integer, start["pid"]
      assert_kind_of Array, start["listening_addresses"]
      assert start["listening_addresses"].any? { |a| a.include?(":#{port}") }, "Expected listening address to include :#{port}"

      shutdown = puma_logs[1]

      assert_equal "puma", shutdown["src"]
      assert_equal "info", shutdown["lvl"]
      assert_kind_of Integer, shutdown["pid"]
    end
  end
end
