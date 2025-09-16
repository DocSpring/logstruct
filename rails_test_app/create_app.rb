#!/usr/bin/env ruby
# typed: true
# frozen_string_literal: true

# Determine Rails version to use before loading bundler
# Silence Ruby warnings early for this process
ENV["RUBYOPT"] = "-W0"
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
  when "8.1"
    "8.1.0.beta1"  # Pre-release lane
  else
    raise "Unrecognized Rails version #{rails_version}"
  end

  puts "Mapping Rails #{rails_version} to #{latest_version}"
  rails_version = latest_version
end

def install_rails_if_missing(version)
  # Robust detection using RubyGems API
  begin
    if Gem::Specification.find_all_by_name("rails", version).any?
      puts "Rails #{version} already installed"
      return
    end
  rescue => e
    warn "Warning: gem spec check failed (#{e}). Falling back to shell check."
    check_cmd = "gem list -i rails -v '#{version}'"
    already = system(check_cmd)
    if already
      puts "Rails #{version} already installed"
      return
    end
  end

  puts "Rails #{version} not found. Installing..."
  pre_flag = /[a-zA-Z]/.match?(version) ? " --pre" : ""
  system("gem install rails -v '#{version}'#{pre_flag} --no-document") || abort("Failed to install Rails #{version}")
end

install_rails_if_missing(rails_version)

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
  unless gem_list_output.include?("1.3.4")
    puts "Installing concurrent-ruby 1.3.4 for Rails 7.0 compatibility..."
    system("gem install concurrent-ruby -v '1.3.4' --no-document")
  end

  # Update GEM_PATH so the gem is available to this script
  ENV["GEM_PATH"] = `gem env gempath`.strip
end

# Suppress noisy constant redefinition warnings during generator
$VERBOSE = nil
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
  # Silence noisy warnings from duplicate gems during generator execution
  "RUBYOPT" => "-W0"
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

  # Use version selector underscore to pick the exact rails generator version.
  # Run in a temporary empty dir to avoid Rails app loader picking up our repo.
  rails_cmd = ["rails", "_#{rails_version}_", "new", RAILS_APP_DIR,
    "--force", "--skip-bundle",
    "--skip-git", "--skip-keeps", "--skip-action-cable",
    "--skip-sprockets", "--skip-javascript", "--skip-hotwire",
    "--skip-jbuilder", "--skip-asset-pipeline", "--skip-bootsnap",
    "--api", "-T"]
  rails_cmd << "--skip-kamal" if @rails_major_minor.start_with?("8.")
  require "tmpdir"
  Dir.mktmpdir("logstruct_rails_new_") do |tmpdir|
    Dir.chdir(tmpdir) do
      puts "=> Running command: #{rails_cmd.join(" ")} (in #{tmpdir})"
      system(clean_env, *rails_cmd) || abort("Failed to create Rails application")
    end
  end

  # Remove the default .rubocop.yml file since it messes up our own RuboCop
  puts "=> Deleting default .rubocop.yml"
  FileUtils.rm_f(File.join(RAILS_APP_DIR, ".rubocop.yml"))

  # Update Gemfile to include the local logstruct gem and test gems
  gemfile_path = File.join(RAILS_APP_DIR, "Gemfile")
  gemfile_content = File.read(gemfile_path)

  # Ensure Rails gem version matches the requested rails_version
  gemfile_content.gsub!(/^\s*gem\s+"rails".*$/, "gem \"rails\", \"~> #{rails_version}\"")

  # Do not force a Ruby version in the generated app; CI matrix will pick Ruby

  # Ensure sqlite3 version compatible with Rails version
  if @rails_major_minor == "7.0"
    if gemfile_content.match?(/^\s*gem\s+"sqlite3"/)
      gemfile_content.gsub!(/^\s*gem\s+"sqlite3".*$/, 'gem "sqlite3", "~> 1.4"')
    else
      # Insert after rails line
      gemfile_content.sub!(/^(\s*gem\s+"rails".*$)/, "\\1\n# Use sqlite3 as the database for Active Record\n gem \"sqlite3\", \"~> 1.4\"")
    end
  elsif gemfile_content.match?(/^\s*gem\s+"sqlite3"/)
    gemfile_content.gsub!(/^\s*gem\s+"sqlite3".*$/, 'gem "sqlite3", ">= 2.1"')
  else
    gemfile_content.sub!(/^(\s*gem\s+"rails".*$)/, "\\1\n# Use sqlite3 as the database for Active Record\n gem \"sqlite3\", \">= 2.1\"")
  end

  # Pin Puma version to exercise both legacy and modern releases across the matrix
  puma_requirement = if @rails_major_minor == "7.0"
    "~> 6.4"
  else
    "~> 7.0"
  end

  if gemfile_content.match?(/^(\s*# Use the Puma web server.*\n)(\s*gem\s+"puma".*$)/)
    gemfile_content.gsub!(
      /(\s*# Use the Puma web server.*\n)\s*gem\s+"puma".*$/,
      "\\1 gem \"puma\", \"#{puma_requirement}\""
    )
  elsif gemfile_content.match?(/^\s*gem\s+"puma"/)
    gemfile_content.gsub!(/^\s*gem\s+"puma".*$/, "gem \"puma\", \"#{puma_requirement}\"")
  else
    gemfile_content.sub!(
      /^(\s*gem\s+"rails".*$)/,
      "\\1\n# Use the Puma web server\n gem \"puma\", \"#{puma_requirement}\""
    )
  end

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
    gem "dotenv-rails"

    # Test gems
    group :test do
      gem 'minitest-reporters'
      gem 'simplecov'
      gem 'simplecov-json'
    end
  GEMS

  # Manage optional integration gems with version matrix
  # We replace any previous managed block to keep things consistent when templates update
  gemfile_content.gsub!(/\n# BEGIN LogStruct integration gems.*?# END LogStruct integration gems\n/m, "\n")

  integration_gems = []
  # Toggle with env var if needed
  include_integrations = (ENV["INCLUDE_INTEGRATION_GEMS"] || "false").strip.downcase == "true"
  if include_integrations
    # Ahoy version matrix
    ahoy_line = nil
    case @rails_major_minor
    when "8.0", "7.2", "7.1"
      ahoy_line = "gem \"ahoy_matey\", \"~> 5.2\""
    when "7.0"
      ahoy_line = "gem \"ahoy_matey\", \"~> 4.1\""
    end
    integration_gems << ahoy_line if ahoy_line

    # ActiveModelSerializers works across 7.x/8.x
    integration_gems << "gem \"active_model_serializers\", \"~> 0.10.13\""
  end

  unless integration_gems.empty?
    managed_block = [
      "# BEGIN LogStruct integration gems\n",
      integration_gems.join("\n"),
      "\n# END LogStruct integration gems\n"
    ].join
    gemfile_content << managed_block
  end

  # Normalize deprecated Windows platform declarations to silence bundler warnings
  # Replace any occurrence of :mingw, :mswin, :x64_mingw with :windows
  gemfile_content.gsub!(%r{platforms:\s*%i\[\s*mingw\s+mswin\s+x64_mingw\s+jruby\s*\]}, "platforms: %i[ windows jruby ]")
  # e.g., %i[ mri mingw x64_mingw ] -> %i[ mri windows ]
  gemfile_content.gsub!(%r{%i\[\s*mri\s+mingw\s+x64_mingw\s*\]}, "%i[ mri windows ]")

  # Have to pin concurrent-ruby to 1.3.4 for Rails 7.0 compatibility
  if rails_version.start_with?("7.0")
    gemfile_content += <<~GEMS
      gem "logger"
      gem "concurrent-ruby", "<= 1.3.4"
    GEMS
  end
  File.write(gemfile_path, gemfile_content)

  # Run initial bundle install later after we copy templates and adjust Gemfile
end

# Copy all template files before bundling and installing ActiveStorage
puts "Copying template files..."
# Use Dir.children to include dotfiles but exclude . and ..
Dir.children(TEMPLATE_DIR).each do |entry|
  copy_template(entry)
end

# Ensure HostAuthorization does not block example test hosts
test_env_path = File.join(RAILS_APP_DIR, "config", "environments", "test.rb")
if File.exist?(test_env_path)
  content = File.read(test_env_path)
  # Remove previous blanket clearing if present
  content.gsub!(/^\s*config\.hosts\.clear\s*\n/, "")
  insert = <<~RUBY
    # Allow test hostnames for integration tests
    config.hosts << "www.example.com"
    config.hosts << "127.0.0.1"
    config.hosts << "localhost"
    config.hosts << /.*\z/
  RUBY
  unless content.include?("config.hosts << \"www.example.com\"")
    content.sub!("Rails.application.configure do", "Rails.application.configure do\n#{insert}")
  end
  File.write(test_env_path, content)
end

# Run bundle install now that templates (and Gemfile edits) are in place
puts "Running initial bundle install..."
Dir.chdir(RAILS_APP_DIR) do
  system(clean_env, "bundle install") || raise("Bundle install failed")
end

# Install ActiveStorage (after bundle and with correct load_defaults)
puts "Setting up ActiveStorage..."
Dir.chdir(RAILS_APP_DIR) do
  system(clean_env, "bin/rails active_storage:install") || abort("ActiveStorage installation failed")
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
