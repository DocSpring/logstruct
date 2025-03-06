#!/usr/bin/env ruby
# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

# Set up load path
$LOAD_PATH.unshift(File.expand_path("../lib/", __dir__))

require_relative "../tools/log_types_exporter"

# Run the exporter
exporter = LogStruct::Tools::LogTypesExporter.new
exporter.export
