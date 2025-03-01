# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

# Load Sorbet tasks
Dir.glob("lib/tasks/*.rake").each { |r| load r }

# Default task runs specs and type checking
task default: [:spec, "sorbet:typecheck"]
