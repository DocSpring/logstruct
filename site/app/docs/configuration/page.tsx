import { Prism as SyntaxHighlighter } from "react-syntax-highlighter";
import { atomDark } from "react-syntax-highlighter/dist/esm/styles/prism";
import { EditPageLink } from "@/components/edit-page-link";

export default function ConfigurationPage() {
  return (
    <div className="space-y-6">
      <h1 className="text-4xl font-bold">Configuration</h1>
      <p className="text-lg text-neutral-600 dark:text-neutral-400">
        LogStruct is designed to be highly configurable while working with sensible defaults. You can customize how and where logs are generated, which integrations are enabled, and how errors are handled.
      </p>
      
      <h2 className="text-2xl font-bold mt-10 mb-4">Basic Configuration</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        While LogStruct works out of the box with minimal configuration, you may want to customize it to suit your application's needs. Create a file at <code className="px-1 py-0.5 bg-neutral-100 dark:bg-neutral-800 rounded">config/initializers/logstruct.rb</code> with your desired configuration.
      </p>
      
      <div className="rounded-lg bg-neutral-100 p-4 dark:bg-neutral-900">
        <SyntaxHighlighter
          language="ruby"
          style={atomDark}
          customStyle={{
            fontSize: "0.875rem",
            fontFamily: "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace",
            backgroundColor: "transparent",
            padding: "0",
            borderRadius: "0px",
          }}
        >
{`# Configure LogStruct
LogStruct.configure do |config|
  # Enable or disable all structured logging
  config.enabled = true
  
  # Specify which environments to enable in
  config.environments = [:development, :test, :production]
  
  # Specify which environments are considered local/development
  config.local_environments = [:development, :test]
  
  # Configure integrations
  config.integrations.enable_lograge = true
  config.integrations.enable_actionmailer = true
  config.integrations.enable_activejob = true
  config.integrations.enable_sidekiq = true
  config.integrations.enable_shrine = true
  config.integrations.enable_activestorage = true
  config.integrations.enable_carrierwave = true
  config.integrations.enable_rack_error_handler = true
  config.integrations.enable_host_authorization = true
  
  # Configure error handling modes
  config.error_handling_modes.logstruct_errors = LogStruct::ErrorHandlingMode::Log
  config.error_handling_modes.security_errors = LogStruct::ErrorHandlingMode::Report
  config.error_handling_modes.standard_errors = LogStruct::ErrorHandlingMode::LogProduction
  
  # Salt for SHA256 hashes in filtered email addresses
  config.filters.hash_salt = ENV['EMAIL_HASH_SALT']
end

# Set up all integrations
LogStruct.initialize`}
        </SyntaxHighlighter>
      </div>
      
      <h2 className="text-2xl font-bold mt-10 mb-4">Environment Configuration</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct supports different environments and handles them appropriately:
      </p>
      
      <div className="rounded-lg bg-neutral-100 p-4 dark:bg-neutral-900">
        <SyntaxHighlighter
          language="ruby"
          style={atomDark}
          customStyle={{
            fontSize: "0.875rem",
            fontFamily: "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace",
            backgroundColor: "transparent",
            padding: "0",
            borderRadius: "0px",
          }}
        >
{`# Enable LogStruct in specific environments
config.environments = [:development, :test, :production]

# Specify which environments are considered local/development
# This affects error handling behavior (fail hard in dev, soft in prod)
config.local_environments = [:development, :test]`}
        </SyntaxHighlighter>
      </div>
      
      <h2 className="text-2xl font-bold mt-10 mb-4">Integration Configuration</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct integrates with many popular gems. You can enable or disable specific integrations:
      </p>
      
      <div className="rounded-lg bg-neutral-100 p-4 dark:bg-neutral-900">
        <SyntaxHighlighter
          language="ruby"
          style={atomDark}
          customStyle={{
            fontSize: "0.875rem",
            fontFamily: "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace",
            backgroundColor: "transparent",
            padding: "0",
            borderRadius: "0px",
          }}
        >
{`# Configure which integrations to enable
config.integrations.enable_lograge = true             # Structured request logging
config.integrations.enable_actionmailer = true        # Email delivery logging
config.integrations.enable_activejob = true           # Background job logging
config.integrations.enable_sidekiq = true             # Sidekiq job logging
config.integrations.enable_shrine = true              # File upload logging (Shrine)
config.integrations.enable_carrierwave = true         # File upload logging (CarrierWave)
config.integrations.enable_activestorage = true       # ActiveStorage operations logging
config.integrations.enable_rack_error_handler = true  # Enhanced error logging middleware
config.integrations.enable_host_authorization = true  # Host authorization violation logging
config.integrations.enable_sorbet_error_handler = true # Sorbet type checking error handling`}
        </SyntaxHighlighter>
      </div>
      
      <h2 className="text-2xl font-bold mt-10 mb-4">Filtering Sensitive Data</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct includes robust filtering for sensitive data to ensure privacy and security:
      </p>
      
      <div className="rounded-lg bg-neutral-100 p-4 dark:bg-neutral-900">
        <SyntaxHighlighter
          language="ruby"
          style={atomDark}
          customStyle={{
            fontSize: "0.875rem",
            fontFamily: "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace",
            backgroundColor: "transparent",
            padding: "0",
            borderRadius: "0px",
          }}
        >
{`# Configure sensitive data filtering
config.filters.email_addresses = true      # Filter email addresses
config.filters.url_passwords = true        # Filter passwords in URLs
config.filters.credit_card_numbers = true  # Filter credit card numbers
config.filters.phone_numbers = true        # Filter phone numbers
config.filters.ssns = true                 # Filter social security numbers
config.filters.ip_addresses = false        # Filter IP addresses (off by default)
config.filters.mac_addresses = false       # Filter MAC addresses (off by default)

# Configure the salt used for hashing filtered email addresses
config.filters.hash_salt = ENV['EMAIL_HASH_SALT']

# Configure the length of hash output for filtered emails (default: 12)
config.filters.hash_length = 12`}
        </SyntaxHighlighter>
      </div>
      
      <h2 className="text-2xl font-bold mt-10 mb-4">Error Handling Configuration</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct provides different error handling modes to control how errors are processed:
      </p>
      
      <div className="rounded-lg bg-neutral-100 p-4 dark:bg-neutral-900">
        <SyntaxHighlighter
          language="ruby"
          style={atomDark}
          customStyle={{
            fontSize: "0.875rem",
            fontFamily: "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace",
            backgroundColor: "transparent",
            padding: "0",
            borderRadius: "0px",
          }}
        >
{`# Configure error handling modes
config.error_handling_modes.logstruct_errors = LogStruct::ErrorHandlingMode::Log
config.error_handling_modes.security_errors = LogStruct::ErrorHandlingMode::Report
config.error_handling_modes.standard_errors = LogStruct::ErrorHandlingMode::LogProduction

# Available error handling modes:
# - LogStruct::ErrorHandlingMode::Ignore       # Completely ignore errors
# - LogStruct::ErrorHandlingMode::Log          # Log errors but don't report them
# - LogStruct::ErrorHandlingMode::LogProduction # Log in production, raise in development
# - LogStruct::ErrorHandlingMode::Report       # Log and report errors to error service
# - LogStruct::ErrorHandlingMode::Raise        # Always raise errors`}
        </SyntaxHighlighter>
      </div>
      
      <h2 className="text-2xl font-bold mt-10 mb-4">Custom Lograge Options</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        You can extend Lograge request logging with custom fields:
      </p>
      
      <div className="rounded-lg bg-neutral-100 p-4 dark:bg-neutral-900">
        <SyntaxHighlighter
          language="ruby"
          style={atomDark}
          customStyle={{
            fontSize: "0.875rem",
            fontFamily: "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace",
            backgroundColor: "transparent",
            padding: "0",
            borderRadius: "0px",
          }}
        >
{`# Provide a custom proc to extend Lograge options
config.lograge_custom_options = ->(event, options) do
  # Add custom fields to the options hash
  options[:user_id] = event.payload[:user_id] if event.payload[:user_id]
  options[:account_id] = event.payload[:account_id] if event.payload[:account_id]
  options
end`}
        </SyntaxHighlighter>
      </div>
      
      <EditPageLink />
    </div>
  );
}