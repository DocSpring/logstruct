# typed: strict

# lib/tasks/coverage_report.rake
namespace :coverage do
  task :merge do
    require "simplecov"
    require "simplecov-json"

    SimpleCov.collate Dir["coverage*/.resultset.json"] do
      formatter SimpleCov::Formatter::MultiFormatter.new([
        SimpleCov::Formatter::HTMLFormatter,
        SimpleCov::Formatter::JSONFormatter
      ])

      coverage_dir "site/public/coverage"
    end
  end
end
