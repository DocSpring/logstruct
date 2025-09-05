#!/usr/bin/env ruby
# typed: strict
# frozen_string_literal: true

require "date"

version = File.read("lib/log_struct/version.rb")[/VERSION\s*=\s*"([^"]+)"/, 1]
abort "Could not determine version from lib/log_struct/version.rb" unless version

changelog = begin
  File.read("CHANGELOG.md")
rescue
  ""
end

# Accept headings like: ## [0.0.2-rc1] - 2025-09-05 or ## 0.0.2-rc1
heading_regex = /^##\s*\[?#{Regexp.escape(version)}\]?/m

if changelog.match?(heading_regex)
  puts "CHANGELOG contains entry for #{version}"
  exit 0
else
  warn "CHANGELOG is missing an entry for version #{version}."
  warn "Add a section like: \n\n## [#{version}] - #{Date.today}"
  exit 1
end
