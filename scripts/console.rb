#!/usr/bin/env ruby
# typed: true
# frozen_string_literal: true

require "bundler/setup"
require "debug"
require "irb"
require "irb/completion"

require_relative "../lib/log_struct"

module LogStruct
  def self.console
    IRB.setup(nil)
    workspace = IRB::WorkSpace.new(binding)
    irb = IRB::Irb.new(workspace)
    IRB.conf[:MAIN_CONTEXT] = irb.context
    trap("SIGINT") { irb.signal_handle }
    catch(:IRB_EXIT) { irb.eval_input }
  end
end

LogStruct.console
