# typed: strict
# frozen_string_literal: true

Dir.glob(File.expand_path("log_types/*.rb", __dir__)).sort.each do |file|
  require_relative file
end
