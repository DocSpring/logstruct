# typed: strict
# frozen_string_literal: true

module LogStruct
  module Log
    module Interfaces
      module RequestFields
        extend T::Sig
        extend T::Helpers

        interface!

        sig { abstract.returns(T.nilable(String)) }
        def path
        end

        sig { abstract.returns(T.nilable(String)) }
        def http_method
        end

        sig { abstract.returns(T.nilable(String)) }
        def source_ip
        end

        sig { abstract.returns(T.nilable(String)) }
        def user_agent
        end

        sig { abstract.returns(T.nilable(String)) }
        def referer
        end

        sig { abstract.returns(T.nilable(String)) }
        def request_id
        end
      end
    end
  end
end
