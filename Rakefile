# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "fileutils"

# Define Minitest task without Rails dependencies
Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false
  t.verbose = true
end

# Load Sorbet tasks
Dir.glob("tasks/*.rake").each { |r| load r }

# Rails application integration tests
desc "Run Rails integration tests"
task :rails_tests do
  script_path = File.expand_path("bin/rails_tests", __dir__)
  system(script_path) || abort("Rails tests failed")
end

# Default task runs tests and type checking
task default: [:test, "sorbet:typecheck"]
