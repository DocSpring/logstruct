# typed: true
# frozen_string_literal: true

namespace :sorbet do
  desc "Run Sorbet type checking"
  task typecheck: :environment do
    puts "Running Sorbet type checking..."
    system("bundle exec srb tc") || abort("Sorbet type checking failed")
  end

  desc "Run Sorbet with RBS signatures"
  task typecheck_rbs: :environment do
    puts "Running Sorbet type checking with RBS signatures..."
    system("bundle exec srb tc --enable-experimental-rbs-signatures") || abort("Sorbet type checking failed")
  end

  desc "Generate RBI files using Tapioca"
  task generate_rbi: :environment do
    puts "Generating RBI files using Tapioca..."
    system("bundle exec tapioca init")
    system("bundle exec tapioca gems")
    system("bundle exec tapioca dsl")
    system("bundle exec tapioca annotations")
  end
end

# Add Sorbet type checking to the default test task
task test: :environment do
  Rake::Task["sorbet:typecheck"].invoke
end
