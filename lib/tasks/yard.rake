# frozen_string_literal: true

require "yard"
require "yard-sorbet"

YARD::Rake::YardocTask.new(:yard) do |t|
  t.files = ["lib/**/*.rb"]
  t.options = ["--no-private", 
               "--protected",
               "--markup=markdown",
               "--markup-provider=redcarpet",
               "--readme=README.md",
               "--title=LogStruct API Documentation",
               "--output-dir=site/public/api"]
  t.stats_options = ["--list-undoc"]
end

desc "Generate YARD documentation and open in browser"
task :'yard:open' => :yard do
  require "launchy"
  Launchy.open("site/public/api/index.html")
rescue LoadError
  puts "Install the 'launchy' gem to open docs automatically"
end

desc "Clean YARD documentation directory"
task :'yard:clean' do
  FileUtils.rm_rf("site/public/api")
end

desc "Regenerate YARD documentation"
task :'yard:regen' => [:'yard:clean', :yard]