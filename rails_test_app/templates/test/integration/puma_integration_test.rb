# typed: true

require "test_helper"
require "open3"
require "timeout"

class PumaIntegrationTest < ActiveSupport::TestCase
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
