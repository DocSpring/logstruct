# typed: strict

# lib/tasks/coverage_report.rake
namespace :coverage do
  task :merge do
    require "simplecov"
    require "simplecov-json"

    resultsets = Dir["coverage*/.resultset.json"]
    puts "Found #{resultsets.count} resultset files"
    puts resultsets.map { |resultset| "- #{resultset}" }.join("\n")

    if resultsets.count != 2
      raise "Expected exactly 2 resultset files, got #{resultsets.count}"
    end

    SimpleCov.collate resultsets do
      formatter SimpleCov::Formatter::MultiFormatter.new([
        SimpleCov::Formatter::HTMLFormatter,
        SimpleCov::Formatter::JSONFormatter
      ])

      coverage_dir "site/public/coverage"
    end
  end
end
