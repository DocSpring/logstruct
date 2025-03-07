#!/usr/bin/env ruby
# typed: true
# frozen_string_literal: true

require "fileutils"
require "rails/version"
require "erb"

# Path constants
ROOT_DIR = File.expand_path("..", __dir__)
TEMPLATE_DIR = File.expand_path("templates", __dir__)
RAILS_APP_DIR = File.expand_path("logstruct_test_app", __dir__)

# Use a clean environment with minimal variables
clean_env = {
  "PATH" => ENV["PATH"],
  "HOME" => ENV["HOME"],
  "RAILS_ENV" => "development"
}

# Determine Rails version to use
rails_version = ENV["RAILS_VERSION"] || "7.0.8"

# Fix for Rails 7.0 compatibility with concurrent-ruby
# See: https://github.com/rails/rails/pull/54264
if rails_version.start_with?("7.0")
  puts "Rails 7.0.x detected - checking concurrent-ruby version..."

  # Check if concurrent-ruby 1.3.5+ is installed
  gem_list_output = `gem list concurrent-ruby`
  if gem_list_output.include?("1.3.5")
    puts "Downgrading concurrent-ruby to 1.3.4 for Rails 7.0 compatibility..."
    system("gem uninstall concurrent-ruby -v '>= 1.3.5' -I")
    system("gem install concurrent-ruby -v '1.3.4'")
  else
    puts "concurrent-ruby version is compatible with Rails 7.0"
  end
end

# Extract major and minor version for migrations
@rails_major_minor = (rails_version.split(".")[0..1] || []).join(".")

# Create directories
FileUtils.mkdir_p(RAILS_APP_DIR)

# Use rails new to create a new application
puts "Creating new Rails application with version #{rails_version}..."
rails_new_command = "rails _#{rails_version}_ new #{RAILS_APP_DIR} --skip-git --skip-keeps --skip-action-cable " \
       "--skip-sprockets --skip-javascript --skip-hotwire --skip-jbuilder --skip-asset-pipeline " \
       "--skip-bootsnap --api -T"
puts "=> Running command: #{rails_new_command}"
system(clean_env, rails_new_command) || abort("Failed to create Rails application")

# Copy template files into the test app
def copy_template(file, target_path = nil)
  source = File.join(TEMPLATE_DIR, file)
  target = target_path || File.join(RAILS_APP_DIR, file)

  if File.directory?(source)
    FileUtils.mkdir_p(target)
    Dir.glob(File.join(source, "*")).each do |sub_file|
      relative_path = sub_file.sub("#{source}/", "")
      copy_template(File.join(file, relative_path), File.join(target, relative_path))
    end
  elsif File.extname(source) == ".erb"
    content = ERB.new(File.read(source)).result(binding)
    target = target.sub(/\.erb$/, "")
    File.write(target, content)
  else
    FileUtils.cp(source, target)
  end
end

# Update Gemfile to include the local logstruct gem and test gems
gemfile_path = File.join(RAILS_APP_DIR, "Gemfile")
gemfile_content = File.read(gemfile_path)

# Print Gemfile content for debugging
puts "Original Gemfile content:"
puts "------------------------"
puts gemfile_content
puts "------------------------"

# Check if sqlite3 is in the Gemfile
puts "SQLite3 in Gemfile: #{gemfile_content.include?("sqlite3") ? "YES" : "NO"}"

# Add LogStruct gem
logstruct_gem_line = "# LogStruct gem from local path\ngem \"logstruct\", path: \"#{ROOT_DIR}\"\n\n"
if gemfile_content.include?("logstruct")
  puts "LogStruct gem already in Gemfile"
else
  # Add after the source line
  gemfile_content.sub!(/^source.*$/, "\\0\n\n#{logstruct_gem_line}")
end

# Pin concurrent-ruby version for Rails 7.0 compatibility if needed
# See: https://github.com/rails/rails/pull/54264
if rails_version.start_with?("7.0")
  puts "Rails 7.0.x detected - pinning concurrent-ruby to 1.3.4 in Gemfile"
  puts "See: https://github.com/rails/rails/pull/54264"
  gemfile_content.sub!(/gem\s+["']rails["'].*$/,
    ["\\0",
      "",
      "# Pin concurrent-ruby for Rails 7.0 compatibility",
      "gem \"concurrent-ruby\", \"1.3.4\"",
      "",
      "# We also need a few other gems to get Rails 7.0.x working:",
      'gem "logger"',
      'gem "bigdecimal"',
      'gem "mutex_m"',
      "",
      "# For testing",
      'gem "drb"'].join("\n"))
end

# Add test gems
test_gems = <<~GEMS

  # Test gems
  group :test do
    gem 'minitest-reporters'
    gem 'simplecov'
    gem 'simplecov-json'
  end
GEMS

# Add the test gems if they're not already there
unless gemfile_content.include?("minitest-reporters") &&
    gemfile_content.include?("simplecov") &&
    gemfile_content.include?("simplecov-json")
  gemfile_content += test_gems
end

File.write(gemfile_path, gemfile_content)

# Run initial bundle install
puts "Running initial bundle install..."
Dir.chdir(RAILS_APP_DIR) do
  system(clean_env, "bundle install") || abort("Bundle install failed")
end

# Copy all template files
puts "Copying template files..."
Dir.glob(File.join(TEMPLATE_DIR, "*")).each do |file|
  relative_path = File.basename(file)
  copy_template(relative_path)
end

# Run bundle install again to ensure all dependencies are correctly resolved
puts "Running final bundle install..."
Dir.chdir(RAILS_APP_DIR) do
  system(clean_env, "bundle install") || abort("Bundle install failed")
end

# Set up the database
puts "Setting up Rails application in #{RAILS_APP_DIR}..."
Dir.chdir(RAILS_APP_DIR) do
  puts "Database configuration:"
  puts "------------------------"
  system("cat config/database.yml")
  puts "------------------------"

  puts "Setting up database..."
  db_command = "bin/rails db:create db:migrate"
  puts "=> Running command: #{db_command}"

  system(clean_env, db_command) || abort("Database setup failed")
end

puts
puts "Test Rails app created successfully in #{RAILS_APP_DIR}"
puts "To run the tests: cd #{RAILS_APP_DIR} && bin/rails test"
