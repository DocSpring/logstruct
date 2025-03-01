# frozen_string_literal: true

require 'digest'

module RailsStructuredLogging
  # Based on https://github.com/ankane/logstop
  # Changes:
  # - Show which type of data was filtered
  # - Include an SHA256 hash for emails so that requests can be traced
  module Logstop
    class << self
      attr_accessor :email_salt

      # Use specific filter strings for each type of sensitive information
      FILTERED_EMAIL_KEY = 'EMAIL'
      FILTERED_CREDIT_CARD_STR = '[CREDIT_CARD]'
      FILTERED_PHONE_STR = '[PHONE]'
      FILTERED_SSN_STR = '[SSN]'
      FILTERED_IP_STR = '[IP]'
      FILTERED_MAC_STR = '[MAC]'
      FILTERED_URL_STR = '\\1[PASSWORD]\\2'

      CREDIT_CARD_REGEX = /\b[3456]\d{15}\b/
      CREDIT_CARD_REGEX_DELIMITERS = /\b[3456]\d{3}[\s+-]\d{4}[\s+-]\d{4}[\s+-]\d{4}\b/
      EMAIL_REGEX = /\b[\w]([\w+.-]|%2B)+(?:@|%40)[a-z\d-]+(?:\.[a-z\d-]+)*\.[a-z]+\b/i
      IP_REGEX = /\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/
      PHONE_REGEX = /\b(?:\+\d{1,2}\s)?\(?\d{3}\)?[\s+.-]\d{3}[\s+.-]\d{4}\b/
      E164_PHONE_REGEX = /(?:\+|%2B)[1-9]\d{6,14}\b/
      SSN_REGEX = /\b\d{3}[\s+-]\d{2}[\s+-]\d{4}\b/
      URL_PASSWORD_REGEX = /((?:\/\/|%2F%2F)[^\s\/]+(?::|%3A))[^\s\/]+(@|%40)/
      MAC_REGEX = /\b[0-9a-f]{2}(?:(?::|%3A)[0-9a-f]{2}){5}\b/i

      def scrub(msg, url_password: true, email: true, credit_card: true, phone: true, ssn: true, ip: false, mac: false, scrubber: nil)
        msg = msg.to_s.dup

        # order filters are applied is important
        msg.gsub!(URL_PASSWORD_REGEX, FILTERED_URL_STR) if url_password

        # Hash emails with SHA256 and a salt
        if email
          msg.gsub!(EMAIL_REGEX) do |match|
            hashed = Digest::SHA256.hexdigest(match + email_salt)[0, 16]
            "[#{[FILTERED_EMAIL_KEY, hashed].join(':')}]"
          end
        end

        if credit_card
          msg.gsub!(CREDIT_CARD_REGEX, FILTERED_CREDIT_CARD_STR)
          msg.gsub!(CREDIT_CARD_REGEX_DELIMITERS, FILTERED_CREDIT_CARD_STR)
        end
        if phone
          msg.gsub!(E164_PHONE_REGEX, FILTERED_PHONE_STR)
          msg.gsub!(PHONE_REGEX, FILTERED_PHONE_STR)
        end
        msg.gsub!(SSN_REGEX, FILTERED_SSN_STR) if ssn
        msg.gsub!(IP_REGEX, FILTERED_IP_STR) if ip
        msg.gsub!(MAC_REGEX, FILTERED_MAC_STR) if mac

        msg = scrubber.call(msg) if scrubber

        msg
      end

      # Get the email salt, using the default if not set
      def email_salt
        @email_salt ||= 'l0g5t0p'
      end
    end
  end
end
