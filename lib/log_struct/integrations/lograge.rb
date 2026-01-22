# typed: strict
# frozen_string_literal: true

begin
  require "lograge"
rescue LoadError
  # Lograge gem is not available, integration will be skipped
end

module LogStruct
  module Integrations
    # Lograge integration for structured request logging
    module Lograge
      extend IntegrationInterface

      LOGRAGE_KNOWN_KEYS = T.let(
        [
          :method,
          :path,
          :format,
          :controller,
          :action,
          :status,
          :duration,
          :view,
          :db,
          :params,
          :request_id,
          :source_ip,
          :user_agent,
          :referer,
          :host,
          :content_type,
          :accept
        ].freeze,
        T::Array[Symbol]
      )

      class << self
        extend T::Sig

        # Set up lograge for structured request logging
        sig { override.params(logstruct_config: LogStruct::Configuration).returns(T.nilable(T::Boolean)) }
        def setup(logstruct_config)
          return nil unless defined?(::Lograge)
          return nil unless logstruct_config.enabled
          return nil unless logstruct_config.integrations.enable_lograge

          configure_lograge(logstruct_config)

          true
        end

        private_class_method

        sig { params(logstruct_config: LogStruct::Configuration).void }
        def configure_lograge(logstruct_config)
          ::Rails.application.configure do
            config.lograge.enabled = true
            # Use a raw formatter that just returns the log struct.
            # The struct is converted to JSON by our Formatter (after filtering, etc.)
            config.lograge.formatter = T.let(
              lambda do |data|
                LogStruct::Integrations::Lograge.build_request_log(data)
              end,
              T.proc.params(hash: T::Hash[T.any(Symbol, String), T.untyped]).returns(Log::Request)
            )

            # Add custom options to lograge
            config.lograge.custom_options = lambda do |event|
              Integrations::Lograge.lograge_default_options(event)
            end
          end
        end

        sig { params(event: ActiveSupport::Notifications::Event).returns(T::Hash[Symbol, T.untyped]) }
        def lograge_default_options(event)
          # Extract essential fields from the payload
          options = event.payload.slice(
            :request_id,
            :host,
            :source_ip
          ).compact

          if event.payload[:params].present?
            options[:params] = event.payload[:params].except("controller", "action")
          end

          # Process headers if available
          process_headers(event, options)

          # Apply custom options from application if provided
          apply_custom_options(event, options)

          options
        end

        # Process headers from the event payload
        sig { params(event: ActiveSupport::Notifications::Event, options: T::Hash[Symbol, T.untyped]).void }
        def process_headers(event, options)
          headers = event.payload[:headers]
          return if headers.blank?

          options[:user_agent] = headers["HTTP_USER_AGENT"]
          options[:referer] = headers["HTTP_REFERER"]
          options[:content_type] = headers["CONTENT_TYPE"]
          options[:accept] = headers["HTTP_ACCEPT"]
        end

        # Apply custom options from the application's configuration
        sig { params(event: ActiveSupport::Notifications::Event, options: T::Hash[Symbol, T.untyped]).void }
        def apply_custom_options(event, options)
          custom_options_proc = LogStruct.config.integrations.lograge_custom_options
          return unless custom_options_proc&.respond_to?(:call)

          # Call the proc with the event and options
          # The proc can modify the options hash directly
          custom_options_proc.call(event, options)
        end

        sig { params(data: T::Hash[T.any(Symbol, String), T.untyped]).returns(Log::Request) }
        def build_request_log(data)
          normalized_data = normalize_lograge_data(data)

          # Coerce common fields to expected types
          status = ((s = normalized_data[:status]) && s.respond_to?(:to_i)) ? s.to_i : s
          duration_ms = ((d = normalized_data[:duration]) && d.respond_to?(:to_f)) ? d.to_f : d
          view = ((v = normalized_data[:view]) && v.respond_to?(:to_f)) ? v.to_f : v
          db = ((b = normalized_data[:db]) && b.respond_to?(:to_f)) ? b.to_f : b

          params = normalized_data[:params]
          params = params.deep_symbolize_keys if params&.respond_to?(:deep_symbolize_keys)

          additional_data = extract_additional_data(normalized_data)

          Log::Request.new(
            http_method: normalized_data[:method]&.to_s,
            path: normalized_data[:path]&.to_s,
            format: normalized_data[:format]&.to_sym,
            controller: normalized_data[:controller]&.to_s,
            action: normalized_data[:action]&.to_s,
            status: status,
            duration_ms: duration_ms,
            view: view,
            database: db,
            params: params,
            request_id: normalized_data[:request_id]&.to_s,
            source_ip: normalized_data[:source_ip]&.to_s,
            user_agent: normalized_data[:user_agent]&.to_s,
            referer: normalized_data[:referer]&.to_s,
            host: normalized_data[:host]&.to_s,
            content_type: normalized_data[:content_type]&.to_s,
            accept: normalized_data[:accept]&.to_s,
            additional_data: additional_data,
            timestamp: Time.now
          )
        end

        sig { params(data: T::Hash[T.any(Symbol, String), T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
        def normalize_lograge_data(data)
          data.each_with_object({}) do |(key, value), normalized|
            normalized[key.to_s.to_sym] = value
          end
        end

        sig { params(data: T::Hash[Symbol, T.untyped]).returns(T.nilable(T::Hash[Symbol, T.untyped])) }
        def extract_additional_data(data)
          extras = T.let({}, T::Hash[Symbol, T.untyped])
          data.each do |key, value|
            next if LOGRAGE_KNOWN_KEYS.include?(key)
            next if value.nil?

            extras[key] = value
          end

          return nil if extras.empty?

          extras
        end
      end
    end
  end
end
