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
        Process.kill("TERM", wait_thr.pid)

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
        rescue
          # already dead
        end
      end

      output = lines.join("\n")
      json_logs = lines.filter_map { |l|
        begin
          JSON.parse(l)
        rescue
          nil
        end
      }
      puma_logs = json_logs.select { |h| h["src"] == "puma" }

      # Expect at least boot + started + shutdown
      assert puma_logs.any? { |h| h["evt"] == "boot" }, "Expected a puma boot event. Output: #{output}\nSTDERR: #{stderr.read}"
      starting = puma_logs.find { |h| h["evt"] == "started" }

      assert starting, "Expected a puma starting event. Output: #{output}"
      assert starting["pid"], "Expected starting event to include pid"
      assert_kind_of Array, starting["listening_addresses"], "Expected listening addresses array"
      exit_events = ["shutdown"]
      has_exit_json = puma_logs.any? { |h| exit_events.include?(h["evt"]) }
      has_raw_exit = lines.any? { |l| l.strip == "Exiting" || l.include?("puma shutdown") }

      assert has_exit_json || has_raw_exit,
        "Expected an exit/shutdown/goodbye event. Output: #{output}"
    end
  end
end
