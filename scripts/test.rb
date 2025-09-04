#!/usr/bin/env ruby
# typed: false
# frozen_string_literal: true

require "bundler/setup"

# Determine if we are running a subset of tests (files specified)
if ARGV.any?
  # Support: file paths, file:line, and -n=pattern
  name_pattern = nil
  files = []

  ARGV.each do |arg|
    if arg =~ /^-n=(.*)/
      name_pattern = Regexp.last_match(1)
    elsif arg.include?(":")
      file, line = arg.split(":", 2)
      if line
        # Map line to nearest preceding `def test_*`
        if File.exist?(file)
          content = File.read(file)
          upto = content.lines[0...line.to_i].join
          method_matches = upto.scan(/def\s+(test_\w+)/)
          if method_matches.any?
            test_method = method_matches.last[0]
            name_pattern = test_method
            puts "Running test method: #{test_method} (from #{file}:#{line})"
          else
            warn "No test method found before line #{line} in #{file}"
          end
        else
          warn "File not found: #{file}"
        end
        files << file
      else
        files << arg
      end
    else
      files << arg
    end
  end

  # Prepare Minitest args before any test files load minitest/autorun
  ARGV.clear
  ARGV.concat(["-n", name_pattern]) if name_pattern

  # Ensure test/lib are on the load path
  $LOAD_PATH.unshift(File.expand_path("../test", __dir__))
  $LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

  # Require each specified test file
  files.uniq.each do |path|
    abs = File.expand_path(path, Dir.pwd)
    require abs
  end

  # When test files require "minitest/autorun" (via test_helper), Minitest will auto-run at exit
  exit 0
else
  require "rake"
  # Load Rake tasks and run the default test task
  load File.expand_path("../Rakefile", __dir__)
  Rake::Task[:test].invoke
end
