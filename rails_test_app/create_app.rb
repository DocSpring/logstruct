#!/usr/bin/env ruby
# typed: true
# frozen_string_literal: true

# Determine Rails version to use before loading bundler
rails_version = ENV["RAILS_VERSION"] || "7.0"

# Map major.minor versions to specific patch versions
# This mapping will be updated by scripts/update_rails_versions.rb
if rails_version.count(".") < 2
  case rails_version
  when "7.0"
    latest_version = "7.0.8.7"  # Updated by update_rails_versions.rb script
  when "7.1"
    latest_version = "7.1.5.1"  # Updated by update_rails_versions.rb script
  when "8.0"
    latest_version = "8.0.1"  # Updated by update_rails_versions.rb script
  else
    puts "Warning: Using unrecognized Rails version #{rails_version}"
  end

  if latest_version
    puts "Mapping Rails #{rails_version} to #{latest_version}"
    rails_version = latest_version
  end
end

# Get currently installed Rails versions
rails_gems = `gem list rails -l`
installed_versions = rails_gems.scan(/rails \(([^)]+)\)/).flatten.first&.split(", ") || []

# Check if we need to install this version
if !installed_versions.include?(rails_version)
  puts "Rails #{rails_version} not found. Installing..."
  system("gem install rails -v '#{rails_version}' --no-document") || abort("Failed to install Rails #{rails_version}")
else
  puts "Rails #{rails_version} already installed"
end

require "bundler/setup"

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
  "RAILS_ENV" => "development",
  "BUNDLE_GEMFILE" => nil,
  "GEM_HOME" => nil,
  "GEM_PATH" => nil,
  "RUBYOPT" => nil
}

# Check if we should skip app creation
skip_app_creation = ENV["SKIP_APP_CREATION"] == "true"

# Extract major and minor version for migrations and load_defaults
@rails_major_minor = rails_version.split(".")[0..1].join(".")

# Create directories
FileUtils.mkdir_p(RAILS_APP_DIR)

# Fix for Rails 7.0 compatibility with concurrent-ruby
# See: https://github.com/rails/rails/pull/54264
if rails_version == "7.0"
  puts "Rails 7.0 detected - checking concurrent-ruby version..."

  # Check if concurrent-ruby 1.3.5+ is installed
  gem_list_output = `gem list concurrent-ruby`
  if gem_list_output.include?("1.3.5")
    puts "Downgrading concurrent-ruby to 1.3.4 for Rails 7.0 compatibility..."
    # First uninstall the incompatible version
    system("gem uninstall concurrent-ruby -v '>= 1.3.5' -I")
  end

  # Always make sure 1.3.4 is installed
  puts "Installing concurrent-ruby 1.3.4 for Rails 7.0 compatibility..."
  system("gem install concurrent-ruby -v '1.3.4' --no-document")

  # Update GEM_PATH so the gem is available to this script
  ENV["GEM_PATH"] = `gem env gempath`.strip
end

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

# Create a new Rails application if not skipping
if !skip_app_creation
  # Use rails new to create a new application
  puts "Creating new Rails application with version #{rails_version}..."
  rails_new_command = "rails _#{rails_version}_ new #{RAILS_APP_DIR} --skip-git --skip-keeps --skip-action-cable " \
         "--skip-sprockets --skip-javascript --skip-hotwire --skip-jbuilder --skip-asset-pipeline " \
         "--skip-bootsnap --api -T"
  puts "=> Running command: #{rails_new_command}"
  system(clean_env, rails_new_command) || abort("Failed to create Rails application")

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

  # Common gems for all Rails versions
  common_gems = <<~GEMS
    # Common gems for all Rails versions
    gem "bigdecimal"
    gem "mutex_m"
    gem "drb"
    gem "benchmark"
  GEMS

  # Add version-specific gems
  case rails_version
  when "7.0"
    latest_version = "7.0.8.7"  # Updated by update_rails_versions.rb script
  when "7.1"
    latest_version = "7.1.5.1"  # Updated by update_rails_versions.rb script
  when "8.0"
    latest_version = "8.0.1"  # Updated by update_rails_versions.rb script
  else
    puts "Warning: Using unrecognized Rails version #{rails_version}"
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
  gemfile_content += test_gems

  File.write(gemfile_path, gemfile_content)

  # Run initial bundle install
  puts "Running initial bundle install..."
  Dir.chdir(RAILS_APP_DIR) do
    system(clean_env, "bundle install") || abort("Bundle install failed")
  end

  # Set up ActiveStorage
  puts "Setting up ActiveStorage..."
  Dir.chdir(RAILS_APP_DIR) do
    # Install ActiveStorage
    system(clean_env, "bin/rails active_storage:install") || abort("ActiveStorage installation failed")
  end
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
  puts "Setting up database..."
  db_command = "bin/rails db:migrate"
  puts "=> Running command: #{db_command}"
  system(clean_env, db_command) || abort("Database setup failed")
end

puts

# Save the Rails version to a file for future comparisons
# Use the original version number (like "7.1") that was requested by the user
version_file = File.join(RAILS_APP_DIR, ".rails_version")
File.write(version_file, ENV["RAILS_VERSION"] || rails_version)
puts "Rails version #{ENV["RAILS_VERSION"] || rails_version} saved to #{version_file}"

puts "Test Rails app created/updated successfully in #{RAILS_APP_DIR}"
puts "To run the tests: cd #{RAILS_APP_DIR} && bin/rails test"
