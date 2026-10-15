#!/usr/bin/env bash
# Boots a Rails app whose bundle has railties and actionpack but not the rest of Rails
# (no Active Record, Active Job, Action Mailer, etc.), and checks that LogStruct sets up
# and logs a request.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APP_DIR="$(mktemp -d)"
trap 'rm -rf "$APP_DIR"' EXIT

cat > "$APP_DIR/Gemfile" <<GEMFILE
source "https://rubygems.org"

gem "logstruct", path: "$PROJECT_ROOT"
gem "railties", "${RAILS_VERSION:->= 7.1}"
# ActiveSupport's JSON encoder passes quirks_mode to JSON.generate, which json 3 rejects
gem "json", "< 3"
GEMFILE

cat > "$APP_DIR/app.rb" <<'RUBY'
require "bundler/setup"
require "rails"
require "action_controller/railtie"
require "logstruct"

class SmokeApp < Rails::Application
  config.load_defaults Rails::VERSION::STRING.to_f
  config.eager_load = false
  config.secret_key_base = "0" * 64
  config.hosts.clear
  config.logger = ActiveSupport::Logger.new(nil)
  routes.append { root "smoke#index" }
end

class SmokeController < ActionController::Base
  def index
    Rails.logger.info("smoke test")
    render plain: "ok"
  end
end

Rails.application.initialize!

status, = Rack::MockRequest.new(Rails.application).get("/").then { |r| [r.status] }
SemanticLogger.flush

missing = %w[activerecord activejob actionmailer activestorage actioncable].select { |name| Gem.loaded_specs.key?(name) }
raise "Bundle includes #{missing.join(", ")}" if missing.any?
raise "Expected 200, got #{status}" unless status == 200
raise "LogStruct isn't enabled" unless LogStruct.enabled?

lines = File.readlines(ENV.fetch("SMOKE_LOG")).map { |line| JSON.parse(line) }
raise "No app log line in #{lines.inspect}" unless lines.any? { |line| line["msg"] == "smoke test" }
raise "No request log line in #{lines.inspect}" unless lines.any? { |line| line["evt"] == "request" && line["status"] == 200 }

puts "Railties-only app booted and logged #{lines.size} JSON lines"
RUBY

mkdir -p "$APP_DIR/log"
cd "$APP_DIR"
unset BUNDLE_GEMFILE BUNDLE_PATH BUNDLE_WITH BUNDLE_WITHOUT RUBYOPT
export BUNDLE_GEMFILE="$APP_DIR/Gemfile"
export BUNDLE_PATH="$APP_DIR/vendor/bundle"
bundle install --quiet
LOGSTRUCT_ENABLED=true RAILS_ENV=production SMOKE_LOG="$APP_DIR/log.jsonl" \
  bundle exec ruby -e 'STDOUT.reopen(ENV.fetch("SMOKE_LOG"), "w"); STDOUT.sync = true; load "app.rb"' ||
  { echo "Smoke test failed. Log output:"; cat "$APP_DIR/log.jsonl"; exit 1; }
tail -1 "$APP_DIR/log.jsonl"
