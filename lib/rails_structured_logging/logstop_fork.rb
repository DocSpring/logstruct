# frozen_string_literal: true

require 'digest'

module RailsStructuredLogging
  # Based on https://github.com/ankane/logstop
  # Changes:
  # - Show which type of data was filtered
  # - Include an SHA256 hash for emails so that requests can be traced
  module LogstopFork
    class << self
      attr_accessor :email_salt

      # Scrub sensitive information from a string
      # @param msg [String] The message to scrub
      # @param url_password [Boolean] Whether to scrub passwords from URLs
      # @param email [Boolean] Whether to scrub email addresses
      # @param credit_card [Boolean] Whether to scrub credit card numbers
      # @param phone [Boolean] Whether to scrub phone numbers
      # @param ssn [Boolean] Whether to scrub social security numbers
      # @param ip [Boolean] Whether to scrub IP addresses
      # @param mac [Boolean] Whether to scrub MAC addresses
      # @param scrubber [Proc] A custom scrubber to apply
      # @return [String] The scrubbed message
      def scrub(msg, url_password: true, email: true, credit_card: true, phone: true, ssn: true, ip: false, mac: false, scrubber: nil)
        msg = msg.to_s.dup

        # URLs with passwords
        if url_password
          msg.gsub!(%r{((?:\/\/|%2F%2F)[^:]+:)[^@\/]+@}, '\1[FILTERED]@')
        end

        # emails
        if email
          msg.gsub!(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i) do |match|
            email_hash = Digest::SHA256.hexdigest("#{match}#{email_salt}")
            "[EMAIL:#{email_hash[0..7]}]"
          end
        end

        # credit card numbers
        if credit_card
          msg.gsub!(/\b[3456]\d{15}\b/, '[CREDIT_CARD]')
          msg.gsub!(/\b[3456]\d{3}[\s-]\d{4}[\s-]\d{4}[\s-]\d{4}\b/, '[CREDIT_CARD]')
        end

        # phone numbers
        if phone
          msg.gsub!(/\b\d{3}[\s-]\d{3}[\s-]\d{4}\b/, '[PHONE]')
        end

        # SSNs
        if ssn
          msg.gsub!(/\b\d{3}[\s-]\d{2}[\s-]\d{4}\b/, '[SSN]')
        end

        # IPs
        if ip
          msg.gsub!(/\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/, '[IP]')
        end

        # MAC addresses
        if mac
          msg.gsub!(/\b[0-9a-f]{2}(:[0-9a-f]{2}){5}\b/i, '[MAC]')
        end

        # custom scrubber
        if scrubber
          msg = scrubber.call(msg)
        end

        msg
      end

      # Get or set the email salt used for hashing emails
      # @return [String] The email salt
      def email_salt
        @email_salt ||= 'l0g5t0p'
      end
    end
  end
end
