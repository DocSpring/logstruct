# typed: strict
# frozen_string_literal: true

require_relative "../enums/log_field"
require_relative "interfaces/request_fields"

module LogStruct
  module Log
    module Shared
      module AddRequestFields
        extend T::Sig
        extend T::Helpers

        requires_ancestor { Interfaces::RequestFields }

        sig { params(hash: T::Hash[Symbol, T.untyped]).void }
        def add_request_fields(hash)
          hash[LogField::Path.serialize] = path if path
          hash[LogField::HttpMethod.serialize] = http_method if http_method
          hash[LogField::SourceIp.serialize] = source_ip if source_ip
          hash[LogField::UserAgent.serialize] = user_agent if user_agent
          hash[LogField::Referer.serialize] = referer if referer
        end
      end
    end
  end
end
