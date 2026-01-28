#!/usr/bin/env ruby
# typed: strict
# frozen_string_literal: true

# Ensure RubyGems and Bundler are set up so gem requires work in CI
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)
require "rubygems"
require "bundler/setup"

require "sorbet-runtime"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "log_struct/enums"

require_relative "../tools/codegen/sorbet_generator"
require_relative "../tools/codegen/log_fields_generator"

root = File.expand_path("..", __dir__)

LogStruct::Codegen::SorbetGenerator.generate_all(root)

system("bundle exec rubocop -A lib/log_struct/log > /dev/null 2>&1")

LogStruct::Codegen::LogFieldsGenerator.generate(root)
