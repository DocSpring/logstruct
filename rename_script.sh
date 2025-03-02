#!/bin/bash
set -e

# Create new directory structure
mkdir -p lib/log_struct
mkdir -p spec/log_struct/integrations

# Move files to new locations (using cp instead of mv to avoid errors if files don't exist)
if [ -d "lib/rails_structured_logging" ]; then
  cp -r lib/rails_structured_logging/* lib/log_struct/ 2>/dev/null || true
fi

if [ -d "spec/rails_structured_logging" ]; then
  cp -r spec/rails_structured_logging/* spec/log_struct/ 2>/dev/null || true
fi

if [ -d "spec/rails_structured_logging/integrations" ]; then
  cp -r spec/rails_structured_logging/integrations/* spec/log_struct/integrations/ 2>/dev/null || true
fi

# Rename main lib file
if [ -f "lib/rails_structured_logging.rb" ]; then
  cp lib/rails_structured_logging.rb lib/logstruct.rb
fi

# Update module references in all files
find . -type f \( -name "*.rb" -o -name "*.gemspec" -o -name "Gemfile" -o -name "*.md" \) -exec sed -i '' 's/RailsStructuredLogging/LogStruct/g' {} \; 2>/dev/null || true

# Update require paths in all files
find . -type f \( -name "*.rb" -o -name "*.gemspec" -o -name "Gemfile" \) -exec sed -i '' 's/rails_structured_logging\//log_struct\//g' {} \; 2>/dev/null || true
find . -type f \( -name "*.rb" -o -name "*.gemspec" -o -name "Gemfile" \) -exec sed -i '' 's/require "rails_structured_logging"/require "logstruct"/g' {} \; 2>/dev/null || true

# Update gem name in files
find . -type f \( -name "*.gemspec" -o -name "Gemfile" -o -name "*.md" \) -exec sed -i '' 's/rails_structured_logging\.gemspec/logstruct.gemspec/g' {} \; 2>/dev/null || true
find . -type f \( -name "*.gemspec" -o -name "Gemfile" -o -name "*.md" \) -exec sed -i '' 's/rails_structured_logging/logstruct/g' {} \; 2>/dev/null || true

# Update GitHub URLs
find . -type f \( -name "*.gemspec" -o -name "*.md" \) -exec sed -i '' 's|github.com/docspring/rails_structured_logging|github.com/docspring/logstruct|g' {} \; 2>/dev/null || true

# Clean up empty directories and old files
if [ -d "lib/rails_structured_logging" ]; then
  rm -rf lib/rails_structured_logging
fi

if [ -d "spec/rails_structured_logging" ]; then
  rm -rf spec/rails_structured_logging
fi

# Delete the old gemspec file
if [ -f "rails_structured_logging.gemspec" ]; then
  rm rails_structured_logging.gemspec
fi

echo "Renaming complete!" 
