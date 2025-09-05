#!/usr/bin/env ruby
# typed: strict
# frozen_string_literal: true

require "date"

version = File.read("lib/log_struct/version.rb")[/VERSION\s*=\s*"([^"]+)"/, 1]
abort "Could not determine version from lib/log_struct/version.rb" unless version

# Skip changelog requirement for RC builds (e.g., 0.0.2-rc1 or 0.0.2.rc1)
if version.match?(/(?:-|\.)rc\d*$/i)
  puts "RC version detected (#{version}); skipping CHANGELOG check."
  exit 0
end

changelog = begin
  File.read("CHANGELOG.md")
rescue
  ""
end

# Accept headings like: ## [0.0.2] - 2025-09-05 or ## 0.0.2
heading_regex = /^##\s*\[?#{Regexp.escape(version)}\]?/m

if changelog.match?(heading_regex)
  puts "CHANGELOG contains entry for #{version}"
  exit 0
else
  warn "CHANGELOG is missing an entry for version #{version}."
  warn "Add a section like: \n\n## [#{version}] - #{Date.today}"
  exit 1
end
