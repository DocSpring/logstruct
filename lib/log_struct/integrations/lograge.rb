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

      # With config.exceptions_app = routes, Rails renders an error page by sending the request through the app again
      # as GET /<status>, and keeps the request's own method and path in these headers
      ORIGINAL_METHOD_HEADER = "action_dispatch.original_request_method"
      ORIGINAL_PATH_HEADER = "action_dispatch.original_path"
      # Set when the request's action logged a line with its error, so the error page for it logs none
      ACTION_ERROR_LOGGED_HEADER = "logstruct.action_error_logged"

      # A Proc, not a Method: sorbet-runtime replaces a method with sig checks on its first call, so a Method taken
      # before then isn't equal to one taken after, and setup couldn't tell it had added the test already
      IGNORE_REPEATED_ERROR_PAGE = T.let(
        ->(event) { Lograge.repeated_error_page?(event) },
        T.proc.params(event: ActiveSupport::Notifications::Event).returns(T::Boolean)
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

            # Lograge detaches Rails' own request lines from ActiveSupport::Notifications. From Rails 8.2 they come
            # from Rails.event, so LogStruct detaches them there.
            config.after_initialize do |app|
              Integrations::Lograge.unsubscribe_rails_request_lines unless app.config.lograge.keep_original_rails_log
            end
          end

          # Lograge.setup adds the app's own ignore tests to the same list
          ::Lograge.ignore(IGNORE_REPEATED_ERROR_PAGE) unless ::Lograge.ignore_tests.include?(IGNORE_REPEATED_ERROR_PAGE)
        end

        # Rails' "Processing by", "Completed 200 OK" and "Rendered" lines, which the request line replaces
        sig { void }
        def unsubscribe_rails_request_lines
          # Earlier Rails versions' subscribers are lograge's to detach
          return unless defined?(::ActiveSupport::EventReporter::LogSubscriber)

          RailsLogSubscribers.unsubscribe_from_events(::ActionController::LogSubscriber) if defined?(::ActionController::LogSubscriber)
          RailsLogSubscribers.unsubscribe_from_events(::ActionView::LogSubscriber) if defined?(::ActionView::LogSubscriber)
        end

        sig { params(event: ActiveSupport::Notifications::Event).returns(T::Hash[Symbol, T.untyped]) }
        def lograge_default_options(event)
          # Extract essential fields from the payload
          options = event.payload.slice(
            :request_id,
            :host,
            :source_ip
          ).compact
          add_request_address(event.payload[:request], options)
          add_error_page_request(event, options)

          if event.payload[:params].present?
            options[:params] = event.payload[:params].except("controller", "action")
          end

          # Process headers if available
          process_headers(event, options)

          # Apply custom options from application if provided
          apply_custom_options(event, options)

          options
        end

        # Rails' payload has the request but not its address, which Rails' own "Started GET" line logs.
        # A payload's own :source_ip and :host (from append_info_to_payload) take precedence.
        sig { params(request: T.untyped, options: T::Hash[Symbol, T.untyped]).void }
        def add_request_address(request, options)
          return unless request.is_a?(::ActionDispatch::Request)

          options[:host] ||= request.host
          options[:source_ip] ||= begin
            request.remote_ip
          rescue ::ActionDispatch::RemoteIp::IpSpoofAttackError
            # The forwarding headers disagree, so the address the connection came from
            request.get_header("REMOTE_ADDR")
          end
        end

        # An error page's line has the method and path of the request it's for, not GET /500
        sig { params(event: ActiveSupport::Notifications::Event, options: T::Hash[Symbol, T.untyped]).void }
        def add_error_page_request(event, options)
          request = event.payload[:request]
          return unless request.is_a?(::ActionDispatch::Request)

          if request.has_header?(ORIGINAL_PATH_HEADER)
            options[:method] = request.get_header(ORIGINAL_METHOD_HEADER)
            options[:path] = "#{request.script_name}#{request.get_header(ORIGINAL_PATH_HEADER)}"
          elsif event.payload[:exception]
            request.set_header(ACTION_ERROR_LOGGED_HEADER, true)
          end
        end

        # The error page for an error its action's line logged would log the request a second time. A request whose
        # error came before any action (a routing error) or after it (in a middleware) keeps its error page's line.
        sig { params(event: ActiveSupport::Notifications::Event).returns(T::Boolean) }
        def repeated_error_page?(event)
          request = event.payload[:request]
          request.is_a?(::ActionDispatch::Request) && request.has_header?(ORIGINAL_PATH_HEADER) &&
            request.get_header(ACTION_ERROR_LOGGED_HEADER) == true
        end

        # Process headers from the event payload
        sig { params(event: ActiveSupport::Notifications::Event, options: T::Hash[Symbol, T.untyped]).void }
        def process_headers(event, options)
          headers = event.payload[:headers]
          return if headers.blank?

          # Rails' ActionDispatch::RequestId middleware stores request_id in headers
          # Only set if not already present in payload (payload takes precedence)
          if options[:request_id].blank? && headers["action_dispatch.request_id"].present?
            options[:request_id] = headers["action_dispatch.request_id"]
          end

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

          # The proc can change options, or return a Hash of fields to add, as Lograge's custom_options do
          result = custom_options_proc.call(event, options)
          return if !result.is_a?(Hash) || result.equal?(options)

          options.merge!(normalize_lograge_data(result))
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
          params = normalize_lograge_data(params) if params.is_a?(Hash) || params.is_a?(::ActionController::Parameters)

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
            source_ip: normalized_data[:source_ip]&.to_s,
            user_agent: normalized_data[:user_agent]&.to_s,
            # Without its query, which can carry reset tokens and OAuth codes
            referer: StringScrubber.without_query(normalized_data[:referer]&.to_s),
            host: normalized_data[:host]&.to_s,
            content_type: normalized_data[:content_type]&.to_s,
            accept: normalized_data[:accept]&.to_s,
            additional_data: additional_data,
            timestamp: Time.now
          )
        end

        sig { params(data: T.untyped).returns(T::Hash[Symbol, T.untyped]) }
        def normalize_lograge_data(data)
          normalized = T.let({}, T::Hash[Symbol, T.untyped])
          truncated = T.let(false, T::Boolean)
          data.each_pair.with_index do |(key, value), index|
            if index >= LogStruct.config.limits.max_hash_keys
              truncated = true
              break
            end
            next if key.to_s.bytesize > LogStruct.config.limits.max_string_bytes

            normalized[key.to_s.to_sym] = value
          end
          if truncated
            normalized[:_more_keys] = data.is_a?(Hash) ? data.size - LogStruct.config.limits.max_hash_keys : true
          end
          normalized
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
