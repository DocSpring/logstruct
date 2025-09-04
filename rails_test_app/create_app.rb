#!/usr/bin/env ruby
# typed: true
# frozen_string_literal: true

# Determine Rails version to use before loading bundler
rails_version = ENV["RAILS_VERSION"] || "7.0"

# Map major.minor versions to specific patch versions
# This mapping will be updated by scripts/update_rails_versions.rb
if rails_version.count(".") < 2
  latest_version = case rails_version
  when "7.0"
    "7.0.8.7"  # Updated by update_rails_versions script
  when "7.1"
    "7.1.5.1"  # Updated by update_rails_versions script
  when "7.2"
    "7.2.2.1"  # Updated by update_rails_versions script
  when "8.0"
    "8.0.1"  # Updated by update_rails_versions script
  else
    raise "Unrecognized Rails version #{rails_version}"
  end

  puts "Mapping Rails #{rails_version} to #{latest_version}"
  rails_version = latest_version
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

# Fix for Rails 7.0 compatibility with concurrent-ruby
# (Have to run this before bundler/setup)
# See: https://github.com/rails/rails/pull/54264
if rails_version.start_with?("7.0")
  puts "Rails 7.0 detected - checking concurrent-ruby version..."

  # Check if concurrent-ruby 1.3.5+ is installed
  gem_list_output = `gem list concurrent-ruby`
  puts "gem_list_output: #{gem_list_output}"
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

require "bundler/setup"
require "fileutils"
require "erb"

# Make the rails_version available as an instance variable for the ERB templates
@rails_version = rails_version

# Path constants
ROOT_DIR = File.expand_path("..", __dir__)
TEMPLATE_DIR = File.expand_path("templates", __dir__)
RAILS_APP_DIR = File.expand_path("logstruct_test_app", __dir__)

# IMPORTANT - Use a clean environment with minimal variables
# Requiring Bundler and Rails sets a bunch of environment variables that break everything
# if we're not careful.
clean_env = {
  "PATH" => ENV["PATH"],
  "HOME" => ENV["HOME"],
  "RAILS_ENV" => "development",
  "RAILS_VERSION" => nil,
  "RUBY_VERSION" => nil,
  "BUNDLE_GEMFILE" => nil,
  "BUNDLER_SETUP" => nil,
  "GEM_HOME" => nil,
  "GEM_PATH" => nil,
  "RUBYOPT" => nil
}

# Remove this repository's bin directory from PATH to avoid invoking local bin/rails
project_bin = File.join(ROOT_DIR, "bin")
path_parts = (clean_env["PATH"] || "").split(File::PATH_SEPARATOR)
path_parts.reject! { |p| p == project_bin }
clean_env["PATH"] = path_parts.join(File::PATH_SEPARATOR)

# Check if we should skip app creation
skip_app_creation = ENV["SKIP_APP_CREATION"] == "true"

# Extract major and minor version for migrations and load_defaults
@rails_major_minor = (rails_version.split(".")[0..1] || []).join(".")

# Create directories
FileUtils.mkdir_p(RAILS_APP_DIR)

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

  # Try using gem's exec command with proper version specification
  require "rbconfig"
  rails_exec = [
    RbConfig.ruby,
    "-e",
    "load Gem.bin_path('railties','rails','#{rails_version}')"
  ]
  rails_args = [
    "new", RAILS_APP_DIR,
    "--skip-git", "--skip-keeps", "--skip-action-cable",
    "--skip-sprockets", "--skip-javascript", "--skip-hotwire",
    "--skip-jbuilder", "--skip-asset-pipeline", "--skip-bootsnap",
    "--api", "-T"
  ]
  cmd = rails_exec + rails_args
  puts "=> Running command: #{cmd.map { |s| s.inspect }.join(" ")}"
  require "tmpdir"
  Dir.mktmpdir("logstruct_rails_new_") do |tmpdir|
    Dir.chdir(tmpdir) do
      T.unsafe(self).system(clean_env, *cmd) || abort("Failed to create Rails application")
    end
  end

  # Remove the default .rubocop.yml file since it messes up our own RuboCop
  puts "=> Deleting default .rubocop.yml"
  FileUtils.rm_f(File.join(RAILS_APP_DIR, ".rubocop.yml"))

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
  gemfile_content += <<~GEMS
    gem "bigdecimal"
    gem "mutex_m"
    gem "drb"
    gem "benchmark"

    # Test gems
    group :test do
      gem 'minitest-reporters'
      gem 'simplecov'
      gem 'simplecov-json'
    end
  GEMS

  # Have to pin concurrent-ruby to 1.3.4 for Rails 7.0 compatibility
  if rails_version.start_with?("7.0")
    gemfile_content += <<~GEMS
      gem "logger"
      gem "concurrent-ruby", "<= 1.3.4"
    GEMS
  end
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
