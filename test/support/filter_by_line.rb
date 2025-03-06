# typed: true
# frozen_string_literal: true

# This file helps to filter tests by line number
# It's used by the bin/test script when a line number is specified

module FilterByLine
  module ClassMethods
    extend T::Helpers
    requires_ancestor { Minitest::Runnable }

    def runnable_methods
      methods = super

      # Get the target line from the environment
      line = ENV["LINE"]&.to_i
      return methods unless line && name&.include?("Test")

      methods.select do |method_name|
        # Couldn't figure out how to get typechecking to pass for #instance_method
        method = T.unsafe(self).instance_method(method_name)
        source_location = method.source_location
        # If source location doesn't contain line info, include the method
        next true unless source_location

        # Include this method if it's defined at or before the target line
        # and the next method is defined after
        _, method_line = source_location
        method_line <= line
      end
    end
  end

  def self.prepended(base)
    base.singleton_class.prepend(ClassMethods)
  end
end

module Minitest
  class Runnable
    prepend FilterByLine
  end
end
