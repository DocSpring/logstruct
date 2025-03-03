# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe LogStruct::LogLevel do
  describe "serialization" do
    it "serializes correctly to symbols" do
      expect(LogStruct::LogLevel::Info.serialize).to eq(:info)
    end
  end
end
