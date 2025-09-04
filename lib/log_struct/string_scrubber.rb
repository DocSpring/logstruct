# typed: strict
# frozen_string_literal: true

require "digest"

module LogStruct
  # StringScrubber is inspired by logstop by @ankane: https://github.com/ankane/logstop
  # Enhancements:
  # - Shows which type of data was filtered
  # - Includes an SHA256 hash with filtered emails for request tracing
  # - Uses configuration options from LogStruct.config
  module StringScrubber
    class << self
      extend T::Sig

      # Also supports URL-encoded URLs like https%3A%2F%2Fuser%3Asecret%40example.com
      # cspell:ignore Fuser Asecret
      URL_PASSWORD_REGEX = /((?:\/\/|%2F%2F)[^\s\/]+(?::|%3A))[^\s\/]+(@|%40)/
      URL_PASSWORD_REPLACEMENT = '\1[PASSWORD]\2'

      EMAIL_REGEX = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i

      CREDIT_CARD_REGEX_SHORT = /\b[3456]\d{15}\b/
      CREDIT_CARD_REGEX_DELIMITERS = /\b[3456]\d{3}[\s-]\d{4}[\s-]\d{4}[\s-]\d{4}\b/
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
      sig { params(string: String).returns(String) }
      def scrub(string)
        return string if string.empty?

        string = string.to_s.dup
        config = LogStruct.config.filters

        # Passwords in URLs
        string.gsub!(URL_PASSWORD_REGEX, URL_PASSWORD_REPLACEMENT) if config.url_passwords

        # Emails
        if config.email_addresses
          string.gsub!(EMAIL_REGEX) do |email|
            email_hash = HashUtils.hash_value(email)
            "[EMAIL:#{email_hash}]"
          end
        end

        # Credit card numbers
        if config.credit_card_numbers
          string.gsub!(CREDIT_CARD_REGEX_SHORT, CREDIT_CARD_REPLACEMENT)
          string.gsub!(CREDIT_CARD_REGEX_DELIMITERS, CREDIT_CARD_REPLACEMENT)
        end

        # Phone numbers
        string.gsub!(PHONE_REGEX, PHONE_REPLACEMENT) if config.phone_numbers

        # SSNs
        string.gsub!(SSN_REGEX, SSN_REPLACEMENT) if config.ssns

        # IPs
        string.gsub!(IP_REGEX, IP_REPLACEMENT) if config.ip_addresses

        # MAC addresses
        string.gsub!(MAC_REGEX, MAC_REPLACEMENT) if config.mac_addresses

        # Custom scrubber
        custom_scrubber = LogStruct.config.string_scrubbing_handler
        string = custom_scrubber.call(string) if !custom_scrubber.nil?

        string
      end
    end
  end
end
