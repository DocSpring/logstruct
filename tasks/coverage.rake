# typed: strict

# lib/tasks/coverage_report.rake
namespace :coverage do
  task :merge do
    require "simplecov"

    SimpleCov.collate Dir["coverage*/.resultset.json"] do
      formatter SimpleCov::Formatter::MultiFormatter.new([
        SimpleCov::Formatter::SimpleFormatter,
        SimpleCov::Formatter::HTMLFormatter
      ])

      coverage_dir "site/public/coverage"
    end
  end
end
