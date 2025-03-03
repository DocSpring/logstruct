# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe LogStruct::Log::Security do
  describe "initialization" do
    it "creates a security log with default values" do
      log = described_class.new(sec_evt: LogStruct::LogSecurityEvent::IPSpoof)

      expect(log.src).to eq(LogStruct::LogSource::Rails)
      expect(log.evt).to eq(LogStruct::LogEvent::Security)
      expect(log.lvl).to eq(LogStruct::LogLevel::Warn)
      expect(log.sec_evt).to eq(LogStruct::LogSecurityEvent::IPSpoof)
      expect(log.data).to eq({})
    end

    it "accepts custom values" do
      log = described_class.new(
        sec_evt: LogStruct::LogSecurityEvent::CSRFError,
        msg: "CSRF token does not match",
        path: "/users/sign_in",
        http_method: "POST",
        source_ip: "1.2.3.4",
        user_agent: "Mozilla/5.0",
        data: { user_id: 123 }
      )

      expect(log.sec_evt).to eq(LogStruct::LogSecurityEvent::CSRFError)
      expect(log.msg).to eq("CSRF token does not match")
      expect(log.path).to eq("/users/sign_in")
      expect(log.http_method).to eq("POST")
      expect(log.source_ip).to eq("1.2.3.4")
      expect(log.user_agent).to eq("Mozilla/5.0")
      expect(log.data).to eq({ user_id: 123 })
    end
  end

  describe "#serialize" do
    it "serializes all fields correctly" do
      log = described_class.new(
        sec_evt: LogStruct::LogSecurityEvent::BlockedHost,
        msg: "Blocked host detected",
        path: "/admin",
        http_method: "GET",
        source_ip: "1.2.3.4",
        user_agent: "Mozilla/5.0",
        referer: "https://example.com",
        request_id: "abc123",
        blocked_host: "evil.example.com",
        blocked_hosts: ["evil1.example.com", "evil2.example.com"],
        data: { additional: "data" }
      )

      serialized = log.serialize

      expect(serialized[:src]).to eq(:rails)
      expect(serialized[:evt]).to eq(:security)
      expect(serialized[:lvl]).to eq(:warn)
      expect(serialized[:sec_evt]).to eq(:blocked_host)
      expect(serialized[:msg]).to eq("Blocked host detected")
      expect(serialized[:path]).to eq("/admin")
      expect(serialized[:method]).to eq("GET") # Note: http_method is serialized as method
      expect(serialized[:source_ip]).to eq("1.2.3.4")
      expect(serialized[:user_agent]).to eq("Mozilla/5.0")
      expect(serialized[:referer]).to eq("https://example.com")
      expect(serialized[:request_id]).to eq("abc123")
      expect(serialized[:blocked_host]).to eq("evil.example.com")
      expect(serialized[:blocked_hosts]).to eq(["evil1.example.com", "evil2.example.com"])
      expect(serialized[:additional]).to eq("data")
    end
  end
end
