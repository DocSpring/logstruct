# typed: strict
# frozen_string_literal: true

begin
  require "yard"
  require "yard-sorbet"
rescue LoadError
  # Yard not available (e.g. from bundle install --without development on CI)
end

if defined?(YARD::Rake::YardocTask)
  YARD::Rake::YardocTask.new(:yard) do |t|
    t.files = ["lib/**/*.rb"]
    t.options = ["--no-private",
      "--protected",
      "--markup=markdown",
      "--markup-provider=redcarpet",
      "--readme=README.md",
      "--title=LogStruct YARD Documentation",
      "--output-dir=docs/public/yard"]
    t.stats_options = ["--list-undoc"]
  end

  desc "Generate YARD documentation and open in browser"
  task "yard:open": :yard do
    require "launchy"
    Launchy.open("docs/public/yard/index.html")
  rescue LoadError
    puts "Install the 'launchy' gem to open docs automatically"
  end

  desc "Clean YARD documentation directory"
  task :"yard:clean" do
    FileUtils.rm_rf("docs/public/yard")
  end

  desc "Regenerate YARD documentation"
  task "yard:regen": [:"yard:clean", :yard]
end
