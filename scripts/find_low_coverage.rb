#!/usr/bin/env ruby
# typed: strict
# frozen_string_literal: true

require "json"
require "pathname"
require "sorbet-runtime"

# Load the coverage JSON file
coverage_file = File.join(File.dirname(__FILE__), "../docs/public/coverage/coverage.json")
coverage_data = JSON.parse(File.read(coverage_file))

# Sort files by coverage percentage
sorted_files = coverage_data["files"].sort_by { |file| file["covered_percent"] }

# Find the project root directory
root_dir = File.expand_path(File.join(File.dirname(__FILE__), ".."))

# Print a table of files with low coverage
puts "Files with lowest coverage percentages:"
puts "| Coverage % | Lines Covered | File Path |"
puts "|------------|---------------|-----------|"

sorted_files.first(20).each do |file|
  filename = file["filename"]
  relative_path = if filename.start_with?(root_dir)
    filename[root_dir.length + 1..]
  else
    filename
  end

  covered_lines = file["covered_lines"]
  total_lines = file["lines_of_code"]
  coverage_percent = file["covered_percent"].round(2)

  puts "| #{coverage_percent}% | #{covered_lines}/#{total_lines} | #{relative_path} |"
end

# Identify files with no tests
puts "\n\nFiles that might need tests:"

lib_files = Dir.glob(File.join(root_dir, "lib/**/*.rb"))
test_files = Dir.glob(File.join(root_dir, "test/**/*_test.rb"))

# Find lib files without corresponding test files
no_test_files = lib_files.select do |lib_file|
  base = File.basename(lib_file, ".rb")
  !test_files.any? { |test_file| File.basename(test_file).include?("#{base}_test.rb") }
end

puts "| File Path | Expected Test Path |"
puts "|-----------|-------------------|"

no_test_files.sort.each do |file|
  relative_path = file[root_dir.length + 1..]
  expected_test_path = T.must(relative_path).gsub("lib/", "test/").gsub(".rb", "_test.rb")
  puts "| #{relative_path} | #{expected_test_path} |"
end
