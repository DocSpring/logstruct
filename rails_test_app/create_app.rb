#!/usr/bin/env ruby
# typed: true
# frozen_string_literal: true

require "fileutils"
require "bundler"
require "rails/version"

# Path constants
ROOT_DIR = File.expand_path("../..", __dir__)
TEMPLATE_DIR = File.expand_path("templates", __dir__)
RAILS_APP_DIR = File.expand_path("logstruct_test_app", __dir__)

# Determine Rails version to use
rails_version = ENV["RAILS_VERSION"] || "7.0.0"

# Create directories
FileUtils.mkdir_p(RAILS_APP_DIR)

# Use rails new to create a new application
system("rails _#{rails_version}_ new #{RAILS_APP_DIR} --skip-git --skip-keeps --skip-action-cable " \
       "--skip-sprockets --skip-javascript --skip-hotwire --skip-jbuilder --skip-asset-pipeline " \
       "--skip-bootsnap --api -T")

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

# Update Gemfile to include the local logstruct gem
gemfile_path = File.join(RAILS_APP_DIR, "Gemfile")
gemfile_content = File.read(gemfile_path)
gemfile_content.sub!(/^# Uncomment the following/, "# LogStruct gem from local path\ngem \"logstruct\", path: \"../..\"\n\n\\0")
File.write(gemfile_path, gemfile_content)

# Copy all template files
Dir.glob(File.join(TEMPLATE_DIR, "*")).each do |file|
  relative_path = File.basename(file)
  copy_template(relative_path)
end

# Set up the database
Dir.chdir(RAILS_APP_DIR) do
  system("bundle install")
  system("bin/rails db:create db:migrate")
end

puts "Test Rails app created successfully in #{RAILS_APP_DIR}"
puts "To run the tests: cd #{RAILS_APP_DIR} && bin/rails test"
