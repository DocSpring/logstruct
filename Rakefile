# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/file_utils"
require "rake/testtask"
require "fileutils"

# The Release workflow publishes each version, after CI passes and the release is approved, with
# RubyGems trusted publishing. Bundler's own release task would push the gem from this machine.
Rake::Task["release"].clear
desc "Releases are published by the Release workflow: run `task gem:release` to push the version's tag"
task :release do
  abort "Releases are published by the Release workflow. Run `task gem:release` to push the version's tag."
end

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
