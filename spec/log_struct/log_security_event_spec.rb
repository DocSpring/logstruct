# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe LogStruct::LogSecurityEvent do
  describe "enum values" do
    it "includes the expected security events" do
      expect(LogStruct::LogSecurityEvent::IPSpoof.serialize).to eq(:ip_spoof)
      expect(LogStruct::LogSecurityEvent::CSRFError.serialize).to eq(:csrf_error)
      expect(LogStruct::LogSecurityEvent::BlockedHost.serialize).to eq(:blocked_host)
    end
  end

  describe "serialization" do
    it "serializes correctly to symbols" do
      expect(LogStruct::LogSecurityEvent::IPSpoof.serialize).to eq(:ip_spoof)
    end
  end
end
