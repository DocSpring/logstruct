#!/usr/bin/env ruby
# typed: true
# frozen_string_literal: true

require "fileutils"
require "bundler/setup"
require "sorbet-runtime"
require "rails/version"
require "erb"
require "logger" # Make sure we have the standard Logger

# Path constants
ROOT_DIR = File.expand_path("..", __dir__)
TEMPLATE_DIR = File.expand_path("templates", __dir__)
RAILS_APP_DIR = File.expand_path("logstruct_test_app", __dir__)

# Determine Rails version to use
rails_version = ENV["RAILS_VERSION"] || "7.0.8"

# Extract major and minor version for migrations
@rails_major_minor = T.must(rails_version.split(".")[0..1]).join(".")

# Create directories
FileUtils.mkdir_p(RAILS_APP_DIR)

# Use rails new to create a new application
puts "Creating new Rails application with version #{rails_version}..."
rails_new_command = "rails _#{rails_version}_ new #{RAILS_APP_DIR} --skip-git --skip-keeps --skip-action-cable " \
       "--skip-sprockets --skip-javascript --skip-hotwire --skip-jbuilder --skip-asset-pipeline " \
       "--skip-bootsnap --api -T"
puts "=> Running command: #{rails_new_command}"
system(rails_new_command) || abort("Failed to create Rails application")

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

# Add LogStruct gem
logstruct_gem_line = "# LogStruct gem from local path\ngem \"logstruct\", path: \"#{ROOT_DIR}\"\n\n"
if gemfile_content.include?("logstruct")
  puts "LogStruct gem already in Gemfile"
else
  # Add after the source line
  gemfile_content.sub!(/^source.*$/, "\\0\n\n#{logstruct_gem_line}")
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

# Run bundle install in the Rails app directory
puts "Running bundle install..."
Dir.chdir(RAILS_APP_DIR) do
  system("bundle install") || abort("Bundle install failed")
end

# Copy all template files
puts "Copying template files..."
Dir.glob(File.join(TEMPLATE_DIR, "*")).each do |file|
  relative_path = File.basename(file)
  copy_template(relative_path)
end

# Set up the database
puts "Setting up Rails application..."
Dir.chdir(RAILS_APP_DIR) do
  puts "Setting up database..."
  system("bin/rails db:create db:migrate") || abort("Database setup failed")
end

puts
puts "Test Rails app created successfully in #{RAILS_APP_DIR}"
puts "To run the tests: cd #{RAILS_APP_DIR} && bin/rails test"
