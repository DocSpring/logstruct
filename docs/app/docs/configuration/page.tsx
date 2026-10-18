import Link from 'next/link';
import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { RubyCodeExample } from '@/components/ruby-code-example';
import { Callout } from '@/components/ui/callout';

export default function ConfigurationPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="configuration" level={1}>
        Configuration
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-300">
        LogStruct works without any configuration. To change its defaults, create{' '}
        <code className="px-1 py-0.5 bg-neutral-100 dark:bg-neutral-800 rounded">
          config/initializers/logstruct.rb
        </code>
        . This page lists every setting.
      </p>

      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        A typical initializer looks like this:
      </p>

      <RubyCodeExample name="rails_initializer" />

      <p className="text-neutral-600 dark:text-neutral-300 mt-4 mb-4">
        Rails passes each request&apos;s instrumentation payload to Lograge, so a controller can add
        fields for <code>lograge_custom_options</code> to read:
      </p>

      <CodeBlock language="ruby" title="app/controllers/application_controller.rb">
        {`class ApplicationController < ActionController::Base
  def append_info_to_payload(payload)
    super
    payload[:user_id] = current_user&.id
  end
end`}
      </CodeBlock>

      <Callout type="info">
        Configure LogStruct in <code>config/initializers</code> (or earlier, in{' '}
        <code>config/application.rb</code> or <code>config/environments/*.rb</code>). LogStruct sets
        up its logger and integrations after the initializers run. A setting changed after the app
        has booted only affects what LogStruct reads as it writes each line, such as the filters and
        limits.
      </Callout>

      <HeadingWithAnchor id="enabling-logstruct">Enabling LogStruct</HeadingWithAnchor>

      <p className="text-neutral-600 dark:text-neutral-300 mb-4">By default LogStruct is on:</p>

      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300 mb-6">
        <li>
          <strong>In production</strong>, for the processes it recognizes: Puma, Unicorn, Thin,
          Falcon, <code>rails server</code>, a Sidekiq server and <code>good_job start</code>.
        </li>
        <li>
          <strong>In test</strong>, for every process except the console, locally and on CI. Keeping
          test close to production catches logging problems (a value that can&apos;t be written, a
          broken integration) before they reach production.
        </li>
      </ul>

      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        It&apos;s off in development, in consoles, and in production Rake tasks,{' '}
        <code>rails runner</code> and job runners it doesn&apos;t recognize (such as Solid
        Queue&apos;s <code>bin/jobs</code>, Resque or Delayed Job), which keep Rails&apos; usual
        logger. <Link href="/docs/when-logstruct-runs">When LogStruct runs</Link> has the details.
      </p>

      <HeadingWithAnchor id="overriding-defaults" level={3}>
        Overriding the Defaults
      </HeadingWithAnchor>

      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        These settings decide whether LogStruct is on, from highest precedence to lowest:
      </p>

      <ol className="list-decimal list-outside ml-6 space-y-3 text-neutral-600 dark:text-neutral-300 mb-6">
        <li>
          <strong>
            The <code>LOGSTRUCT_ENABLED</code> environment variable
          </strong>
          <br />
          <code>true</code>, <code>t</code>, <code>yes</code>, <code>y</code> or <code>1</code>{' '}
          turns LogStruct on in any process and environment, consoles included. Any other value
          turns it off.
          <div className="mt-2">
            <CodeBlock language="bash">
              {`# See the JSON lines in development, or in a console or Rake task
LOGSTRUCT_ENABLED=true bin/rails server
LOGSTRUCT_ENABLED=true bin/rails console
LOGSTRUCT_ENABLED=true bin/rails db:migrate

# Turn LogStruct on for a job runner it doesn't recognize
LOGSTRUCT_ENABLED=true bin/jobs

# Turn it off in tests
LOGSTRUCT_ENABLED=false bin/rails test`}
            </CodeBlock>
          </div>
        </li>
        <li>
          <strong>
            <code>config.enabled</code> in an initializer
          </strong>
          <br />
          It has no environment check of its own: it applies to every process that loads the
          initializer, in every environment. Wrap it in a condition:
          <div className="mt-2">
            <RubyCodeExample name="enable_in_development" />
          </div>
        </li>
        <li>
          <strong>
            <code>config.enabled_environments</code>
          </strong>
          <br />
          The environments where LogStruct switches on for the processes it recognizes (default{' '}
          <code>[:test, :production]</code>).
        </li>
      </ol>

      <HeadingWithAnchor id="environment-configuration">
        Environment Configuration
      </HeadingWithAnchor>

      <RubyCodeExample name="environment_configuration" />

      <p className="text-neutral-600 dark:text-neutral-300 mt-4">
        In the environments that aren&apos;t local (production, staging and any other), LogStruct
        logs to STDOUT only. In local environments it also writes Rails&apos; log file (
        <code>log/development.log</code>, <code>log/test.log</code>). In test it writes{' '}
        <em>only</em> the log file, so test output stays clean. With{' '}
        <code>RAILS_LOG_TO_STDOUT</code> set, every environment logs to STDOUT only. See{' '}
        <Link href="/docs/logging">Logging to STDOUT</Link>.
      </p>

      <HeadingWithAnchor id="development-preview">Logger Settings</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        When LogStruct is on in development, it writes the same JSON as production, so you can check
        your lines locally. For colored, pretty-printed lines instead, set{' '}
        <code>prefer_json_in_development</code> to <code>false</code>. These are the logger settings
        and their defaults:
      </p>

      <RubyCodeExample name="logger_settings" />

      <HeadingWithAnchor id="integration-configuration">
        Integration Configuration
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        Each integration can be turned off. The <Link href="/docs/integrations">integrations</Link>{' '}
        page describes the lines each one writes.
      </p>

      <RubyCodeExample name="integrations_configuration" />

      <p className="text-neutral-600 dark:text-neutral-300 mt-4 mb-4">
        The integrations&apos; other settings, with their defaults:
      </p>

      <RubyCodeExample name="integration_settings" />

      <HeadingWithAnchor id="filtering-sensitive-data">Filtering Sensitive Data</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        Every setting for filtering keys and scrubbing strings, with the defaults where the example
        doesn&apos;t change them:
      </p>

      <RubyCodeExample name="filter_configuration" />

      <Callout type="info">
        Add to the default lists with <code>+=</code> (as above). Assigning a new list replaces the
        defaults. The <Link href="/docs/filtering-sensitive-data">Filtering Sensitive Data</Link>{' '}
        page explains what each setting matches.
      </Callout>

      <HeadingWithAnchor id="limits">Limits</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct writes only part of very large values, so a huge request body or Hash can&apos;t
        slow down the thread that writes your logs. Long strings are scrubbed before they&apos;re
        cut.
      </p>

      <RubyCodeExample name="limits_configuration" />

      <HeadingWithAnchor id="error-handling-configuration">
        Error Handling Configuration
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct sorts the errors it handles into four groups, each with a mode. The modes are:
      </p>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300 mb-4">
        <li>
          <code>Ignore</code>: do nothing.
        </li>
        <li>
          <code>Log</code>: write an error line.
        </li>
        <li>
          <code>Report</code>: write an error line and report the error.
        </li>
        <li>
          <code>LogProduction</code> and <code>ReportProduction</code>: log, or log and report,
          outside the <code>local_environments</code>; raise in them (development and test by
          default).
        </li>
        <li>
          <code>Raise</code>: raise the error everywhere, without logging or reporting it.
        </li>
      </ul>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">The groups and their defaults:</p>

      <RubyCodeExample name="error_handling_modes" />

      <p className="text-neutral-600 dark:text-neutral-300 mt-4">
        A raised error reaches your app as usual, so your error reporter still sees it. Reports go
        to the first of Sentry, Bugsnag, Rollbar and Honeybadger that your app loads; with none of
        them, LogStruct logs the error instead. To use another service, set a{' '}
        <Link href="#custom-error-reporting">custom error reporting handler</Link>.
      </p>

      <HeadingWithAnchor id="actionmailer-id-mapping">ActionMailer ID Mapping</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        <code>config.integrations.actionmailer_id_mapping</code> lists the mailer instance variables
        whose IDs are added to mail lines, so you can see which account or user an email was sent
        for. With the default mapping (<code>{'{account: :account_id, user: :user_id}'}</code>),
        this mailer&apos;s lines get <code>account_id</code> and <code>user_id</code> fields:
      </p>

      <CodeBlock language="ruby">
        {`class UserMailer < ApplicationMailer
  def welcome_email(user, account)
    @user = user        # user_id
    @account = account  # account_id
    mail(to: user.email, subject: "Welcome")
  end
end`}
      </CodeBlock>

      <HeadingWithAnchor id="custom-lograge-options">Custom Lograge Options</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        Request lines include the method, path, format, controller, action, status, durations (
        <code>duration_ms</code>, <code>view</code>, <code>db</code>), params (as Rails filtered
        them), <code>source_ip</code>, <code>host</code>, <code>user_agent</code>,{' '}
        <code>referer</code> (without its query string), <code>content_type</code> and{' '}
        <code>accept</code>, and <code>req_id</code>. To add your own fields:
      </p>

      <RubyCodeExample name="lograge_custom_options" />
      <p className="text-neutral-600 dark:text-neutral-300 mt-4">
        The fields are added at the top level of the request line, and filtered like everything
        else.
      </p>
      <p className="text-neutral-600 dark:text-neutral-300 mt-4">
        With <code>config.exceptions_app = routes</code>, Rails renders an error page by sending the
        request through your routes again as <code>GET /500</code> (or <code>/404</code>,{' '}
        <code>/422</code>). Each request still has one request line: when an action raises, its line
        has the error&apos;s status and the error page logs none. When the error comes before any
        action (a routing error) or after it (in a middleware), the error page&apos;s line is
        logged, with the request&apos;s own method and path.
      </p>

      <HeadingWithAnchor id="custom-string-scrubbing">Custom String Scrubbing</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        To scrub values the built-in scrubbers don&apos;t know about:
      </p>

      <RubyCodeExample name="custom_string_scrubber" />

      <HeadingWithAnchor id="custom-error-reporting">Custom Error Reporting</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        If LogStruct doesn&apos;t support your error reporting service, register a handler. (Or send
        a PR!)
      </p>

      <RubyCodeExample name="error_reporting_handler" />

      <p className="text-neutral-600 dark:text-neutral-300 mt-4 mb-4">
        If the handler raises (a timeout calling your service), LogStruct logs its error as a{' '}
        <code>logstruct</code> error line, and the error it was reporting is handled as it would
        have been.
      </p>

      <p className="text-neutral-600 dark:text-neutral-300 mt-4 mb-4">
        When your app loads more than one of the supported services, choose one:
      </p>

      <RubyCodeExample name="choose_error_reporter" />

      <HeadingWithAnchor id="sorbet-integration">Sorbet Integration</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct sets Sorbet&apos;s runtime error handlers, so a type error anywhere in your app or
        its gems is raised in development and test, and logged and reported in production while your
        app carries on (<code>error_handling_modes.type_checking_errors</code>). Without LogStruct,
        Sorbet raises them everywhere. The handlers replace any your app set before LogStruct&apos;s
        initializer ran.
      </p>

      <RubyCodeExample name="sorbet_error_handlers_configuration" />

      <EditPageLink />
    </div>
  );
}
