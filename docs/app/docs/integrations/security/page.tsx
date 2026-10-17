import Link from 'next/link';
import type { ReactNode } from 'react';
import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { RubyCodeExample } from '@/components/ruby-code-example';
import { Callout } from '@/components/ui/callout';

function FieldTable({ rows }: { rows: [string, ReactNode][] }) {
  return (
    <div className="relative overflow-x-auto">
      <table className="w-full text-sm text-left text-neutral-600 dark:text-neutral-300">
        <thead className="text-neutral-700 dark:text-neutral-300 border-b border-neutral-200 dark:border-neutral-700">
          <tr>
            <th scope="col" className="px-4 py-2 font-medium">
              Field
            </th>
            <th scope="col" className="px-4 py-2 font-medium">
              Value
            </th>
          </tr>
        </thead>
        <tbody>
          {rows.map(([field, value]) => (
            <tr key={field} className="border-b border-neutral-200 dark:border-neutral-700">
              <td className="px-4 py-2 font-mono text-xs align-top whitespace-nowrap">{field}</td>
              <td className="px-4 py-2">{value}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

// What happens after a CSRF or IP spoofing line is written, for each security_errors mode
const MODE_ROWS: [string, ReactNode][] = [
  ['Ignore, Log', 'Nothing more.'],
  ['Report (default)', 'The error is reported to your error tracker.'],
  ['LogProduction', 'Production: nothing more. Local environments: as Raise.'],
  ['ReportProduction', 'Production: the error is reported. Local environments: as Raise.'],
  [
    'Raise',
    <>
      LogStruct raises the error inside Rails&apos; <code>DebugExceptions</code> interceptor. Rails
      rescues it and responds as usual. The error isn&apos;t reported.
    </>,
  ],
];

export default function SecurityIntegrationPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="security" level={1}>
        Security Lines
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-300">
        LogStruct writes a <code>security</code> line when Rails blocks a request for a host it
        doesn&apos;t allow, when a request fails Rails&apos; CSRF checks, and when Rails finds
        conflicting client IP headers (IP spoofing). Rails still handles each request as it would
        without LogStruct. CSRF and IP spoofing errors are also reported to your error tracker by
        default. Blocked hosts are logged only.
      </p>

      <HeadingWithAnchor id="blocked-hosts">Blocked hosts</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        Rails&apos; <code>HostAuthorization</code> middleware blocks requests whose{' '}
        <code>Host</code> header isn&apos;t in <code>config.hosts</code>, and it&apos;s only active
        where <code>config.hosts</code> isn&apos;t empty. Rails fills it in development; in test and
        production it&apos;s empty unless your app sets it. LogStruct gives the middleware a
        response app that writes a <code>warn</code> line, then responds:
      </p>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          with your app&apos;s own <code>config.host_authorization[:response_app]</code>, if it set
          one (other <code>host_authorization</code> settings such as <code>exclude</code> are
          kept);
        </li>
        <li>
          otherwise with a 403 and a short &quot;Blocked Host&quot; HTML page, in every environment.
          (Without LogStruct, Rails responds with a 403 and an empty body, or with its own
          blocked-host page where it shows detailed exceptions, as in development.)
        </li>
      </ul>
      <CodeBlock language="json">
        {`{
  "src": "security",
  "evt": "blocked_host",
  "lvl": "warn",
  "ts": "2026-10-17T03:21:07.025+00:00",
  "path": "/health",
  "method": "GET",
  "source_ip": "203.0.113.10",
  "user_agent": "Mozilla/5.0 (test)",
  "referer": "https://app.example.com/posts/1",
  "msg": "Blocked host detected: evil.example.com",
  "blocked_host": "evil.example.com",
  "blocked_hosts": [
    "evil.example.com"
  ],
  "prog": "Rails"
}`}
      </CodeBlock>
      <p className="text-neutral-600 dark:text-neutral-300">
        This line has no <code>req_id</code>: <code>HostAuthorization</code> runs before the
        middleware that sets it. It isn&apos;t reported, whatever{' '}
        <code>error_handling_modes.security_errors</code> says.
      </p>

      <HeadingWithAnchor id="csrf">CSRF errors</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        With <code>protect_from_forgery with: :exception</code> (Rails&apos; default for{' '}
        <code>ActionController::Base</code>), Rails raises{' '}
        <code>ActionController::InvalidAuthenticityToken</code> for a request without a valid CSRF
        token, and <code>ActionController::InvalidCrossOriginRequest</code> when another site embeds
        a JavaScript response in a <code>&lt;script&gt;</code> tag. LogStruct registers an
        interceptor with Rails&apos; <code>DebugExceptions</code> middleware, which is in the stack
        in every environment and sees the error before <code>ShowExceptions</code> turns it into a
        response. Both errors are an <code>error</code> line with the event{' '}
        <code>csrf_violation</code> and the error&apos;s message in <code>msg</code>:
      </p>
      <CodeBlock language="json">
        {`{
  "src": "security",
  "evt": "csrf_violation",
  "lvl": "error",
  "ts": "2026-10-17T03:21:07.337+00:00",
  "path": "/comments",
  "method": "POST",
  "source_ip": "203.0.113.10",
  "user_agent": "Mozilla/5.0 (test)",
  "referer": "https://app.example.com/posts/1",
  "msg": "Can't verify CSRF token authenticity.",
  "prog": "Rails",
  "req_id": "08ab2f67-38ce-4348-9ea7-a615e856b069"
}`}
      </CodeBlock>
      <p className="text-neutral-600 dark:text-neutral-300">
        Rails then responds as usual: 422 Unprocessable Content for both errors (in production, your{' '}
        <code>public/422.html</code>). Rails&apos; own lines for the request are still written too,
        such as its &quot;Can&apos;t verify CSRF token authenticity.&quot; warning.
      </p>

      <HeadingWithAnchor id="ip-spoofing">IP spoofing</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        Rails raises <code>ActionDispatch::RemoteIp::IpSpoofAttackError</code> from{' '}
        <code>request.remote_ip</code> when the <code>Client-IP</code> and{' '}
        <code>X-Forwarded-For</code> headers disagree (with{' '}
        <code>config.action_dispatch.ip_spoofing_check</code> on, the default). It raises it only
        where something reads <code>remote_ip</code>: a request with those headers to an action that
        never reads it gets no line and its usual response. Where it&apos;s raised, the line is{' '}
        <code>warn</code> level:
      </p>
      <CodeBlock language="json">
        {`{
  "src": "security",
  "evt": "ip_spoof",
  "lvl": "warn",
  "ts": "2026-10-17T03:21:07.379+00:00",
  "path": "/whoami",
  "method": "GET",
  "source_ip": "203.0.113.10",
  "user_agent": "Mozilla/5.0 (test)",
  "referer": "https://app.example.com/posts/1",
  "msg": "IP spoofing attack?! HTTP_CLIENT_IP=\\"198.51.100.1\\" HTTP_X_FORWARDED_FOR=\\"192.0.2.7\\"",
  "client_ip": "198.51.100.1",
  "x_forwarded_for": "192.0.2.7",
  "prog": "Rails",
  "req_id": "459628a4-7c21-4ffc-8471-6b23c2e2f408"
}`}
      </CodeBlock>
      <p className="text-neutral-600 dark:text-neutral-300">
        Rails doesn&apos;t map this error to a status, so it responds with a 500 (in production,
        your <code>public/500.html</code>); in tests that don&apos;t render exceptions, the error is
        raised. An error raised in your controllers is logged by the <code>DebugExceptions</code>{' '}
        interceptor. One raised by a middleware outside <code>ShowExceptions</code> is logged by
        LogStruct&apos;s error middleware, which sits just before{' '}
        <code>ActionDispatch::RemoteIp</code> and raises the error again for your server to handle.
      </p>

      <HeadingWithAnchor id="fields">Fields</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">Every security line has:</p>
      <FieldTable
        rows={[
          ['path', 'The request path, without the query string.'],
          ['method', 'The HTTP method.'],
          [
            'source_ip',
            <>
              The client&apos;s IP: Rails&apos; <code>remote_ip</code> on CSRF lines, Rack&apos;s{' '}
              <code>request.ip</code> on blocked host and IP spoofing lines (and on CSRF lines when
              the request&apos;s IP headers are spoofed).
            </>,
          ],
          ['user_agent', 'The User-Agent header.'],
          [
            'referer',
            'The Referer header, without its query and fragment, which can carry reset or confirmation tokens.',
          ],
          ['msg', "What happened (for CSRF and IP spoofing, the error's message)."],
          [
            'req_id',
            'The request ID, on CSRF and IP spoofing lines, as on every line logged during the request.',
          ],
        ]}
      />
      <p className="text-neutral-600 dark:text-neutral-300">And per event:</p>
      <FieldTable
        rows={[
          ['blocked_host', "blocked_host: the request's host."],
          [
            'blocked_hosts',
            'blocked_host: every host Rails blocked: the Host header, and X-Forwarded-Host when the request has one.',
          ],
          [
            'x_forwarded_for',
            'blocked_host and ip_spoof: the X-Forwarded-For header, when the request has one.',
          ],
          ['client_ip', 'ip_spoof: the Client-IP header.'],
        ]}
      />
      <p className="text-neutral-600 dark:text-neutral-300">
        IP addresses are written as they are unless you turn on <code>filters.ip_addresses</code>{' '}
        (see{' '}
        <Link href="/docs/filtering-sensitive-data" className="underline">
          Filtering Sensitive Data
        </Link>
        ), which writes them as <code>[IP]</code>, in <code>msg</code> too.
      </p>

      <HeadingWithAnchor id="reporting">Reporting</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        The CSRF and IP spoofing lines are written in every mode.{' '}
        <code>config.error_handling_modes.security_errors</code> decides what happens next. A
        reported error is passed once to your error tracker (or <code>error_reporting_handler</code>
        ) with the request&apos;s path, method, user agent and referer. &quot;Local
        environments&quot; are those in <code>local_environments</code> (development and test by
        default).
      </p>
      <div className="relative overflow-x-auto">
        <table className="w-full text-sm text-left text-neutral-600 dark:text-neutral-300">
          <thead className="text-neutral-700 dark:text-neutral-300 border-b border-neutral-200 dark:border-neutral-700">
            <tr>
              <th scope="col" className="px-4 py-2 font-medium">
                security_errors
              </th>
              <th scope="col" className="px-4 py-2 font-medium">
                After the line
              </th>
            </tr>
          </thead>
          <tbody>
            {MODE_ROWS.map(([mode, result]) => (
              <tr key={mode} className="border-b border-neutral-200 dark:border-neutral-700">
                <td className="px-4 py-2 font-mono text-xs align-top whitespace-nowrap">{mode}</td>
                <td className="px-4 py-2">{result}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <HeadingWithAnchor id="settings">Settings</HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          <code>config.integrations.enable_host_authorization</code> (default <code>true</code>):
          blocked host lines.
        </li>
        <li>
          <code>config.integrations.enable_rack_error_handler</code> (default <code>true</code>):
          CSRF and IP spoofing lines, and the error lines for errors that get past Rails&apos;{' '}
          <code>ShowExceptions</code>.
        </li>
        <li>
          <code>config.error_handling_modes.security_errors</code> (default <code>Report</code>).
        </li>
      </ul>
      <p className="text-neutral-600 dark:text-neutral-300">
        See{' '}
        <Link href="/docs/configuration#error-handling-configuration" className="underline">
          Error Handling Configuration
        </Link>{' '}
        for the modes.
      </p>
      <RubyCodeExample name="security_configuration" />

      <HeadingWithAnchor id="not-logged">Not logged</HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          CSRF failures that Rails doesn&apos;t raise: with{' '}
          <code>protect_from_forgery with: :null_session</code> or <code>:reset_session</code>, only
          Rails&apos; own warning line is written. Rails&apos; test environment turns forgery
          protection off, so tests have no CSRF lines unless they turn it on.
        </li>
        <li>
          CSRF errors your controllers handle with their own <code>rescue_from</code>: they never
          reach <code>DebugExceptions</code>.
        </li>
        <li>
          Spoofed IP headers on requests where nothing reads <code>remote_ip</code>.
        </li>
      </ul>

      <Callout type="info">
        Other errors your app doesn&apos;t handle are <code>rails</code> error lines, written where
        Rails would log its own block of text, with the response&apos;s <code>status</code>. They
        aren&apos;t reported by LogStruct: your error tracker&apos;s Rails integration reports them,
        as it would without LogStruct. See{' '}
        <Link href="/docs/troubleshooting#unhandled-errors" className="underline">
          Troubleshooting
        </Link>
        .
      </Callout>

      <EditPageLink />
    </div>
  );
}
