# typed: true
# frozen_string_literal: true

require "digest"

module RailsStructuredLogging
  # Based on https://github.com/ankane/logstop
  # Changes:
  # - Show which type of data was filtered
  # - Include an SHA256 hash for emails so that requests can be traced
  # - Added configuration options to control what gets filtered
  module LogstopFork
    class << self
      # Scrub sensitive information from a string
      # @param msg [String] The message to scrub
      # @param scrubber [Proc] A custom scrubber to apply
      # @return [String] The scrubbed message
      def scrub(msg, scrubber: nil)
        msg = msg.to_s.dup
        config = RailsStructuredLogging.configuration

        # URLs with passwords
        msg.gsub!(%r{((?://|%2F%2F)[^:]+:)[^@/]+@}, '\1[FILTERED]@') if config.filter_url_passwords

        # emails
        if config.filter_emails
          msg.gsub!(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i) do |match|
            email_hash = Digest::SHA256.hexdigest("#{match}#{email_salt}")
            "[EMAIL:#{email_hash[0..7]}]"
          end
        end

        # credit card numbers
        if config.filter_credit_cards
          msg.gsub!(/\b[3456]\d{15}\b/, "[CREDIT_CARD]")
          msg.gsub!(/\b[3456]\d{3}[\s-]\d{4}[\s-]\d{4}[\s-]\d{4}\b/, "[CREDIT_CARD]")
        end

        # phone numbers
        msg.gsub!(/\b\d{3}[\s-]\d{3}[\s-]\d{4}\b/, "[PHONE]") if config.filter_phones

        # SSNs
        msg.gsub!(/\b\d{3}[\s-]\d{2}[\s-]\d{4}\b/, "[SSN]") if config.filter_ssns

        # IPs
        msg.gsub!(/\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/, "[IP]") if config.filter_ips

        # MAC addresses
        msg.gsub!(/\b[0-9a-f]{2}(:[0-9a-f]{2}){5}\b/i, "[MAC]") if config.filter_macs

        # custom scrubber
        msg = scrubber.call(msg) if scrubber

        msg
      end

      attr_writer :email_salt
      # Get or set the email salt used for hashing emails
      # @return [String] The email salt
      def email_salt
        @email_salt ||= "l0g5t0p"
      end
    end
  end
end
