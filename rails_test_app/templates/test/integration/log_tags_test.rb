# typed: true
# frozen_string_literal: true

require "test_helper"

# Rails tags each request's lines with config.log_tags through Rails::Rack::Logger
class LogTagsTest < ActiveSupport::TestCase
  def setup
    @log_output = StringIO.new
    ::SemanticLogger.clear_appenders!
    ::SemanticLogger.add_appender(io: @log_output, formatter: LogStruct::SemanticLogger::Formatter.new, async: false)
  end

  test "lines logged during a request have the config.log_tags tags" do
    app = ->(_env) {
      Rails.logger.info("Inside the request")
      [200, {}, ["OK"]]
    }
    rack_logger = Rails::Rack::Logger.new(app, ["checkout", ->(request) { request.path }])

    rack_logger.call(Rack::MockRequest.env_for("/orders/42")).last.close
    ::SemanticLogger.flush

    line = @log_output.string.lines.map { |l| JSON.parse(l) }.find { |l| l["msg"] == "Inside the request" }

    assert line, "Expected the line logged in the request. Output:\n#{@log_output.string}"
    assert_equal ["checkout", "/orders/42"], line["tags"]
  end
end
