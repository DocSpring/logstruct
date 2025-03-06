#!/usr/bin/env ruby
# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

# Set up load path
$LOAD_PATH.unshift(File.expand_path("../lib/", __dir__))

require_relative "../tools/log_types_exporter"

# Parse command line options
require "optparse"

output_file = LogStruct::Tools::LogTypesExporter::DEFAULT_OUTPUT_FILE

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

  opts.on("-o", "--output FILE", "Output file path") do |file|
    output_file = T.cast(file, String)
  end

  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit
  end
end.parse!

# Create the exporter and run it
puts "Exporting LogStruct types to JSON..."
puts "Output file: #{output_file}"

# Run the exporter
exporter = LogStruct::Tools::LogTypesExporter.new(output_file)
exporter.export

puts "Done! JSON type definitions generated at #{output_file}"
