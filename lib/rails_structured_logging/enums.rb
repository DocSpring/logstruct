# typed: strict
# frozen_string_literal: true

module RailsStructuredLogging
  module Enums; end
end

Dir.glob(File.expand_path("enums/*.rb", __dir__)).sort.each do |file|
  require_relative file
end
