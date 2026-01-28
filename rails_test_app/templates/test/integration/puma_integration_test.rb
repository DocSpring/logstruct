# typed: true

require "test_helper"
require "open3"
require "timeout"
require "net/http"

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

    lines, stderr_output = with_process(
      env: env,
      cmd: cmd,
      ready_timeout: 15,
      ready_matchers: ["Listening on", "Use Ctrl-C to stop", /"evt":"start"/]
    ) { |_lines, _stdout, _stderr, _wait_thr| }

    output = lines.join("\n")

    json_lines = lines.filter_map do |l|
      JSON.parse(l) if l.strip.start_with?("{")
    rescue JSON::ParserError
      nil
    end

    assert_predicate json_lines,
      :any?,
      "Expected JSON logs from direct puma invocation (Puma::Server detection should enable LogStruct).\n" \
      "STDOUT: #{output}\nSTDERR: #{stderr_output}"

    puma_logs = json_lines.select { |h| h["src"] == "puma" }

    assert_predicate puma_logs,
      :any?,
      "Expected puma lifecycle logs. JSON logs: #{json_lines.inspect}"
  end

  def test_rails_server_emits_structured_puma_logs_and_on_exit
    port = 32123
    env = rails_server_env
    cmd = rails_server_cmd(port)

    lines, stderr_output = with_process(
      env: env,
      cmd: cmd,
      ready_timeout: 10,
      ready_matchers: ["Use Ctrl-C to stop"]
    ) { |_lines, _stdout, _stderr, _wait_thr| }

    output = lines.join("\n")
    lines.filter_map { |l|
      begin
        JSON.parse(l)
      rescue
        nil
      end
    }
    first_json_index = lines.find_index { |l|
      l.strip.start_with?("{") && begin
        JSON.parse(l)
      rescue
        nil
      end
    }

    assert first_json_index, "Did not find any JSON log lines. Output: #{output}\nSTDERR: #{stderr_output}"
    after_lines = lines[first_json_index..]
    after_json = after_lines.filter_map do |l|
      JSON.parse(l)
    rescue JSON::ParserError
      nil
    end
    puma_logs = after_json.select { |h| h["src"] == "puma" }

    assert_equal 2, puma_logs.length, "Expected exactly 2 Puma logs. Output: #{output}\nSTDERR: #{stderr_output}"

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

  def test_puma_cluster_mode_emits_request_logs
    port = 32125
    env = {
      "RAILS_ENV" => "test",
      "RAILS_LOG_TO_STDOUT" => "1",
      "LOGSTRUCT_ENABLED" => "true",
      "SECRET_KEY_BASE" => "test_secret_key_base_for_production_mode_1234567890"
    }
    cmd = ["bundle", "exec", "puma", "-p", port.to_s, "-e", "test", "-w", "2", "--preload"]

    Open3.popen3(env, *cmd) do |stdin, stdout, stderr, wait_thr|
      stdin.close
      lines = T.let([], T::Array[String])
      err_lines = T.let([], T::Array[String])
      mutex = Mutex.new
      ready = T.let(false, T::Boolean)
      handle_line = lambda do |stripped|
        should_parse = T.let(false, T::Boolean)
        mutex.synchronize do
          lines << stripped
          if stripped.include?("Listening on")
            ready = true
          elsif stripped.start_with?("{")
            should_parse = true
          end
        end
        return unless should_parse

        begin
          data = JSON.parse(stripped)
        rescue JSON::ParserError
          data = nil
        end

        return unless data.is_a?(Hash)

        mutex.synchronize do
          if data["src"] == "puma" && data["evt"] == "start"
            ready = true
          end
        end
      end

      stdout_thread = Thread.new do
        while (line = stdout.gets)
          stripped = line.strip
          handle_line.call(stripped)
        end
      end

      stderr_thread = Thread.new do
        while (line = stderr.gets)
          stripped = line.strip
          mutex.synchronize { err_lines << stripped }
          handle_line.call(stripped)
        end
      end

      begin
        Timeout.timeout(20) do
          loop do
            break if mutex.synchronize { ready }
            sleep 0.05
          end
        end

        response = Net::HTTP.get_response(URI("http://127.0.0.1:#{port}/logging/request"))

        assert_equal "200", response.code

        found = T.let(false, T::Boolean)
        Timeout.timeout(10) do
          loop do
            snapshot = mutex.synchronize { lines.dup }
            snapshot.each do |entry|
              next unless entry.start_with?("{")
              begin
                data = JSON.parse(entry)
              rescue JSON::ParserError
                next
              end
              if data["evt"] == "request" && data["path"] == "/logging/request"
                found = true
                break
              end
            end
            break if found
            sleep 0.05
          end
        end

        unless found
          stdout_output = mutex.synchronize { lines.join("\n") }
          stderr_output = mutex.synchronize { err_lines.join("\n") }

          flunk("Expected request log from cluster-mode puma. STDOUT:\n#{stdout_output}\nSTDERR:\n#{stderr_output}")
        end
      ensure
        terminate_process(wait_thr, timeout: 10)
        stdout_thread.join(2)
        stderr_thread.join(2)
      end
    end
  end
end
