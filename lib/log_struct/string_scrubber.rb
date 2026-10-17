# typed: strict
# frozen_string_literal: true

require "uri"
require_relative "hash_utils"
require_relative "param_filters"

module LogStruct
  # StringScrubber is inspired by logstop by @ankane: https://github.com/ankane/logstop
  # Enhancements:
  # - Shows which type of data was filtered
  # - Includes a hash of each filtered email (HashUtils) for request tracing
  # - Uses configuration options from LogStruct.config
  module StringScrubber
    class << self
      extend T::Sig

      # The password in a URL's user info (postgres://user:password@host, redis://:password@host).
      # The user ends at its first colon; the password runs to the last @ before the host.
      URL_PASSWORD_REGEX = %r{(//[^\s/:@]*:)[^\s/]+(@)}
      # The same in a URL-encoded URL, like https%3A%2F%2Fuser%3Asecret%40example.com
      # cspell:ignore Fuser Asecret
      ENCODED_URL_PASSWORD_REGEX = %r{(%2F%2F(?:(?!%3A|%2F|%40)[^\s/&])*%3A)(?:(?!%2F)[^\s/&])+(%40)}i
      URL_PASSWORD_REPLACEMENT = '\1[PASSWORD]\2'

      # A URL's query string, for the sensitive params in it
      QUERY_STRING_REGEX = /\?([^\s#"'<>]+)/
      # OAuth authorization codes, which no key pattern would filter
      SENSITIVE_QUERY_PARAMS = T.let(["code"].freeze, T::Array[String])
      QUERY_PARAM_REPLACEMENT = "[FILTERED]"

      EMAIL_REGEX = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i

      # 13 to 19 digits, written together, in fours (4111 1111 1111 1111, with a 19-digit card's last
      # three) or in American Express and Diners Club groups (3782 822463 10005). Numbers that fail
      # the Luhn check are left alone, so most IDs and timestamps are too.
      CREDIT_CARD_REGEX = /
        (?<![A-Za-z0-9.-])
        (?:
          [2-6]\d{12,18}
          | [2-6]\d{3}(?<sep>[\ -])\d{4}\k<sep>\d{4}\k<sep>\d{4}(?:\k<sep>\d{3})?
          | 3\d{3}(?<sep2>[\ -])\d{6}\k<sep2>\d{4,5}
        )
        (?![A-Za-z0-9]|-\d)
      /x
      CREDIT_CARD_REPLACEMENT = "[CREDIT_CARD]"

      PHONE_REGEX = /\b\d{3}[\s-]\d{3}[\s-]\d{4}\b/
      PHONE_REPLACEMENT = "[PHONE]"

      SSN_REGEX = /\b\d{3}[\s-]\d{2}[\s-]\d{4}\b/
      SSN_REPLACEMENT = "[SSN]"

      IP_REGEX = /\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/
      IP_REPLACEMENT = "[IP]"

      MAC_REGEX = /\b[0-9a-f]{2}(:[0-9a-f]{2}){5}\b/i
      MAC_REPLACEMENT = "[MAC]"

      # Hash keys and Symbols like these are never changed by the scrubbers, so they're skipped
      IDENTIFIER_REGEX = /\A[A-Za-z_][A-Za-z0-9_]*\z/

      # Scrub sensitive information from a string
      sig { params(string: String).returns(String) }
      def scrub(string)
        return string if string.empty?

        string = string.to_s.dup
        config = LogStruct.config.filters

        # Sensitive params in URLs' query strings
        scrub_query_params!(string) if config.url_query_params && string.include?("?")

        # Passwords in URLs
        if config.url_passwords
          string.gsub!(URL_PASSWORD_REGEX, URL_PASSWORD_REPLACEMENT)
          string.gsub!(ENCODED_URL_PASSWORD_REGEX, URL_PASSWORD_REPLACEMENT) if string.include?("%")
        end

        # Emails
        if config.email_addresses
          string.gsub!(EMAIL_REGEX) do |email|
            email_hash = HashUtils.hash_value(email)
            "[EMAIL:#{email_hash}]"
          end
        end

        # Credit card numbers
        if config.credit_card_numbers
          string.gsub!(CREDIT_CARD_REGEX) do |number|
            luhn_valid?(number.delete(" -")) ? CREDIT_CARD_REPLACEMENT : number
          end
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

      # A Hash key or a Symbol, scrubbed like a String unless it's a plain identifier (user_id,
      # createdAt). Returns it unchanged, or the scrubbed String when scrubbing changed it.
      sig { params(name: T.untyped).returns(T.untyped) }
      def scrub_name(name)
        return name unless name.is_a?(String) || name.is_a?(Symbol)

        string = name.to_s
        return name if IDENTIFIER_REGEX.match?(string)

        scrubbed = scrub(string)
        (scrubbed == string) ? name : scrubbed
      end

      # The URL without its query string and fragment (for Referer headers)
      sig { params(url: T.nilable(String)).returns(T.nilable(String)) }
      def without_query(url)
        return url if url.nil?

        url.split(/[?#]/, 2).first || ""
      end

      private

      # Replaces the values of query params whose names would be filtered as keys
      # (/reset?token=abc&page=2 becomes /reset?token=[FILTERED]&page=2)
      sig { params(string: String).void }
      def scrub_query_params!(string)
        string.gsub!(QUERY_STRING_REGEX) do
          query = T.must(Regexp.last_match(1))
          params = query.split("&", -1).map do |param|
            name, value = param.split("=", 2)
            next param if value.nil? || value.empty? || value == QUERY_PARAM_REPLACEMENT

            sensitive_query_param?(T.must(name), value) ? "#{name}=#{QUERY_PARAM_REPLACEMENT}" : param
          end
          "?#{params.join("&")}"
        end
      end

      # user[password] is checked as password, written plainly or URL-encoded
      sig { params(name: String, value: String).returns(T::Boolean) }
      def sensitive_query_param?(name, value)
        decoded = begin
          URI.decode_www_form_component(name)
        rescue ArgumentError
          name
        end
        key = decoded[/\[([^\[\]]*)\]\z/, 1] || decoded
        return false if key.empty?

        SENSITIVE_QUERY_PARAMS.include?(key.downcase) || ParamFilters.should_filter_key?(key, value)
      end

      # The Luhn checksum that every card number passes
      sig { params(digits: String).returns(T::Boolean) }
      def luhn_valid?(digits)
        sum = 0
        digits.reverse.each_char.with_index do |char, index|
          digit = char.to_i
          if index.odd?
            digit *= 2
            digit -= 9 if digit > 9
          end
          sum += digit
        end
        (sum % 10).zero?
      end
    end
  end
end
