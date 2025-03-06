# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

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

# Default task runs tests and type checking
task default: [:test, "sorbet:typecheck"]
