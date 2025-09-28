#!/usr/bin/env ruby
# typed: strict
# frozen_string_literal: true

require "json"

threshold = (ENV["COVERAGE_MIN"] || "80").to_f
coverage_path = File.expand_path(File.join(__dir__, "..", "docs/public/coverage/coverage.json"))

unless File.exist?(coverage_path)
  warn "Coverage file not found at #{coverage_path}. Did you run merge_coverage.sh?"
  exit 1
end

data = JSON.parse(File.read(coverage_path))
percent = data.dig("metrics", "covered_percent").to_f

puts "Total coverage: #{format("%.2f", percent)}% (threshold: #{threshold}%)"

if percent < threshold
  warn "Coverage threshold not met: #{percent}% < #{threshold}%"
  exit 1
end

exit 0
