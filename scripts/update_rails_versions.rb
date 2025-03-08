#!/usr/bin/env ruby
# This script fetches the latest patch versions for each supported Rails version
# and updates them in the codebase.

require "json"
require "net/http"

# Rails versions we support
SUPPORTED_MAJOR_MINOR = ["7.0", "7.1", "8.0"]

# Files to update
CREATE_APP_SCRIPT = File.expand_path("../rails_test_app/create_app.rb", __dir__)
GITHUB_WORKFLOW = File.expand_path("../.github/workflows/test.yml", __dir__)

def fetch_latest_rails_versions
  puts "Fetching latest Rails versions from RubyGems.org..."
  uri = URI("https://rubygems.org/api/v1/versions/rails.json")
  response = Net::HTTP.get(uri)
  versions = JSON.parse(response)
  
  # Filter out prerelease versions and map by version number
  stable_versions = versions.reject { |v| v["prerelease"] }.map { |v| v["number"] }
  
  # Find latest patch version for each supported major.minor
  latest_patches = {}
  SUPPORTED_MAJOR_MINOR.each do |major_minor|
    matching = stable_versions.select { |v| v.start_with?("#{major_minor}.") }
    next if matching.empty?
    
    # Sort by version parts to find latest
    latest = matching.sort_by { |v| v.split(".").map(&:to_i) }.last
    latest_patches[major_minor] = latest
  end
  
  puts "Latest patch versions:"
  latest_patches.each do |mm, version|
    puts "  - Rails #{mm}: #{version}"
  end
  
  latest_patches
end

def update_create_app_script(versions)
  puts "\nUpdating rails_test_app/create_app.rb..."
  
  content = File.read(CREATE_APP_SCRIPT)
  
  # Look for the case statement with Rails version mapping
  case_pattern = /case\s+rails_version\s*\n(.*?)end/m
  
  if content.match(case_pattern)
    # Replace the case statement with updated versions
    new_case = "case rails_version\n"
    versions.each do |major_minor, version|
      new_case += "  when \"#{major_minor}\"\n"
      new_case += "    latest_version = \"#{version}\"  # Updated by update_rails_versions script\n"
    end
    new_case += "  else\n"
    new_case += "    puts \"Warning: Using unrecognized Rails version \#{rails_version}\"\n"
    new_case += "  end"
    
    updated_content = content.gsub(case_pattern, new_case)
    File.write(CREATE_APP_SCRIPT, updated_content)
    puts "  Updated create_app.rb with latest versions"
  else
    puts "  Warning: Could not find case statement in create_app.rb"
    puts "  You may need to manually update the Rails versions"
  end
end

def update_github_workflow(versions)
  puts "\nUpdating .github/workflows/test.yml..."
  
  content = File.read(GITHUB_WORKFLOW)
  updated_content = content.dup
  
  # Update the pilot test Rails version
  if updated_content.match(/RAILS_VERSION:\s*'8\.0[\.\d]*'/)
    updated_content.gsub!(/RAILS_VERSION:\s*'8\.0[\.\d]*'/, "RAILS_VERSION: '#{versions['8.0']}'")
    puts "  Updated pilot test Rails version to #{versions['8.0']}"
  else
    puts "  Warning: Could not find RAILS_VERSION for pilot test in test.yml"
  end
  
  # Update the matrix versions
  versions.each do |major_minor, version|
    # Look for matrix entries with this major.minor version
    # Allow for different patch versions (e.g., .8, .8.7)
    if updated_content.match(/rails:\s*'#{major_minor}[\.\d]+'/)
      updated_content.gsub!(/rails:\s*'#{major_minor}[\.\d]+'/, "rails: '#{version}'")
      puts "  Updated matrix Rails #{major_minor} to version #{version}"
    else
      puts "  Warning: Could not find matrix entry for Rails #{major_minor} in test.yml"
    end
  end
  
  File.write(GITHUB_WORKFLOW, updated_content)
  puts "  Updated test.yml with latest versions"
end

# Main execution
versions = fetch_latest_rails_versions
update_create_app_script(versions)
update_github_workflow(versions)

puts "\nDone! Rails versions have been updated to the latest patches."
puts "Remember to commit these changes if they look good."