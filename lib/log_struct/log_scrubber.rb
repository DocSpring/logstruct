# typed: strong
# frozen_string_literal: true

require "digest"

module LogStruct
  # LogScrubber is a fork of logstop by @ankane: https://github.com/ankane/logstop
  # Changes:
  # - Shows which type of data was filtered
  # - Includes an SHA256 hash with filtered emails for request tracing
  # - Uses configuration options from LogStruct.config
  module LogScrubber
    class << self
      URL_PASSWORD_REGEX = %r{((?://|%2F%2F)[^:]+:)[^@/]+@}
      URL_PASSWORD_REPLACEMENT = '\1[FILTERED]@'

      EMAIL_REGEX = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i

      CREDIT_CARD_SHORT_REGEX = /\b[3456]\d{15}\b/
      CREDIT_CARD_LONG_REGEX = /\b[3456]\d{3}[\s-]\d{4}[\s-]\d{4}[\s-]\d{4}\b/
      CREDIT_CARD_REPLACEMENT = "[CREDIT_CARD]"

      PHONE_REGEX = /\b\d{3}[\s-]\d{3}[\s-]\d{4}\b/
      PHONE_REPLACEMENT = "[PHONE]"

      SSN_REGEX = /\b\d{3}[\s-]\d{2}[\s-]\d{4}\b/
      SSN_REPLACEMENT = "[SSN]"

      IP_REGEX = /\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/
      IP_REPLACEMENT = "[IP]"

      MAC_REGEX = /\b[0-9a-f]{2}(:[0-9a-f]{2}){5}\b/i
      MAC_REPLACEMENT = "[MAC]"

      # Scrub sensitive information from a string
      sig { params(msg: String).returns(String) }
      def scrub(msg)
        msg = msg.to_s.dup
        config = LogStruct.config

        # Passwords in URLs
        msg.gsub!(URL_PASSWORD_REGEX, URL_PASSWORD_REPLACEMENT) if config.filter_url_passwords

        # Emails
        if config.filter_emails
          msg.gsub!(EMAIL_REGEX) do |match|
            email_hash = Digest::SHA256.hexdigest("#{match}#{config.hash_salt}")
            "[EMAIL:#{email_hash[0..config.hash_length]}]"
          end
        end

        # Credit card numbers
        if config.filter_credit_cards
          msg.gsub!(CREDIT_CARD_SHORT_REGEX, CREDIT_CARD_REPLACEMENT)
          msg.gsub!(CREDIT_CARD_LONG_REGEX, CREDIT_CARD_REPLACEMENT)
        end

        # Phone numbers
        msg.gsub!(PHONE_REGEX, PHONE_REPLACEMENT) if config.filter_phones

        # SSNs
        msg.gsub!(SSN_REGEX, SSN_REPLACEMENT) if config.filter_ssns

        # IPs
        msg.gsub!(IP_REGEX, IP_REPLACEMENT) if config.filter_ips

        # MAC addresses
        msg.gsub!(MAC_REGEX, MAC_REPLACEMENT) if config.filter_macs

        # custom scrubber
        log_scrubbing_handler = config.log_scrubbing_handler
        msg = log_scrubbing_handler.call(msg) if !log_scrubbing_handler.nil?

        msg
      end
    end
  end
end
