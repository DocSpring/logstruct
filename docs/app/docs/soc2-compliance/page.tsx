import type { Metadata } from 'next';
import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { Callout } from '@/components/ui/callout';

export const metadata: Metadata = {
  title: 'SOC 2 Compliance | LogStruct',
  description:
    'How LogStruct helps companies meet SOC 2 compliance requirements through type-safe, accurate logging with comprehensive sensitive data protection.',
};

export default function SOC2CompliancePage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="soc2-compliance" level={1}>
        SOC 2 Compliance
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-300">
        LogStruct is designed to help companies meet SOC 2 compliance requirements through
        type-safe, accurate logging with comprehensive sensitive data protection.
      </p>

      <HeadingWithAnchor id="why-logging-matters-for-soc2" level={2}>
        Why Logging Matters for SOC 2
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        SOC 2 audits require organizations to demonstrate robust security controls and incident
        response capabilities. Logging plays a critical role in two key areas:
      </p>

      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-300 mb-6">
        <li>
          <strong>Forensic Analysis</strong> - Logs must be accurate and reliable for investigating
          security incidents and breaches
        </li>
        <li>
          <strong>Data Privacy</strong> - Logs must not contain sensitive customer data that could
          violate privacy requirements
        </li>
      </ul>

      <p className="text-neutral-600 dark:text-neutral-300 mb-6">
        LogStruct addresses both requirements by ensuring log accuracy through type safety and
        protecting sensitive data through comprehensive filtering.
      </p>

      <HeadingWithAnchor id="type-safe-logs-for-forensics" level={2}>
        Type-Safe Logs for Forensic Analysis
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct guarantees that your logs contain only known, expected values by enforcing strict
        type checking at runtime. If any value in your logs has the wrong type, your integration
        tests will immediately fail with a clear error.
      </p>

      <Callout type="success">
        <strong>Catch bugs before production:</strong> Type errors in logs are caught in your test
        suite, not in production where they could compromise forensic investigations.
      </Callout>

      <HeadingWithAnchor id="sensitive-data-protection" level={2}>
        Sensitive Data Protection
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct provides powerful filtering capabilities enabled by default to keep sensitive data
        out of your logs while preserving the information needed for debugging and request tracing.
      </p>

      <HeadingWithAnchor id="what-gets-filtered" level={3}>
        What Gets Filtered
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct automatically filters common sensitive fields including:
      </p>

      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-300 mb-6">
        <li>Passwords, tokens, and API keys</li>
        <li>Credit card numbers and CVV codes</li>
        <li>Social security numbers and other PII</li>
        <li>Email addresses and phone numbers</li>
        <li>Any custom sensitive fields you configure</li>
      </ul>

      <HeadingWithAnchor id="smart-filtering-preserves-context" level={3}>
        Smart Filtering Preserves Context
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        Unlike simple redaction that removes all information, LogStruct preserves valuable context
        for debugging:
      </p>

      <CodeBlock language="json">
        {`{
  "email": {
    "_filtered": {
      "_class": "String",
      "_hash": "a1b2c3d4e5f6"  // Deterministic hash for correlation
    }
  },
  "payment_data": {
    "_filtered": {
      "_class": "Hash",
      "_size": 3  // Size helps understand data volume
    }
  }
}`}
      </CodeBlock>

      <HeadingWithAnchor id="deterministic-hashes" level={4}>
        Deterministic Email Hashes
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        For email addresses, LogStruct generates deterministic hashes that allow you to:
      </p>

      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-300 mb-6">
        <li>
          <strong>Trace requests across services</strong> - The same email always produces the same
          hash
        </li>
        <li>
          <strong>Correlate user actions</strong> - Follow a user&apos;s journey without exposing
          their email
        </li>
        <li>
          <strong>Debug user-specific issues</strong> - Identify patterns for a specific user using
          their hash
        </li>
      </ul>

      <HeadingWithAnchor id="filtered-type-information" level={4}>
        Filtered Type Information
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        Knowing the type of filtered data helps with debugging:
      </p>

      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-300 mb-6">
        <li>
          <strong>_class</strong> - Shows whether it was a String, Hash, Array, etc.
        </li>
        <li>
          <strong>_size</strong> - For collections, shows how many items were filtered
        </li>
        <li>
          <strong>_hash</strong> - Deterministic hash for correlation (email addresses only)
        </li>
      </ul>

      <HeadingWithAnchor id="soc2-audit-benefits" level={2}>
        Benefits for SOC 2 Audits
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct helps satisfy multiple SOC 2 trust service criteria:
      </p>

      <HeadingWithAnchor id="security-availability" level={3}>
        Security & Availability (CC6.1, CC7.2)
      </HeadingWithAnchor>
      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-300 mb-6">
        <li>
          <strong>Incident detection</strong> - Type-safe logs ensure reliable security monitoring
          and alerting
        </li>
        <li>
          <strong>Forensic analysis</strong> - Accurate, structured logs enable effective incident
          investigation
        </li>
        <li>
          <strong>Audit trails</strong> - Consistent log format makes it easy to track system
          activities
        </li>
      </ul>

      <HeadingWithAnchor id="confidentiality" level={3}>
        Confidentiality (CC6.6)
      </HeadingWithAnchor>
      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-300 mb-6">
        <li>
          <strong>Data protection</strong> - Automatic filtering prevents sensitive data from
          entering logs
        </li>
        <li>
          <strong>Compliance by default</strong> - No manual scrubbing or post-processing required
        </li>
        <li>
          <strong>Audit evidence</strong> - Clear filtering metadata demonstrates data protection
          controls
        </li>
      </ul>

      <HeadingWithAnchor id="privacy" level={3}>
        Privacy (P3.1, P3.2)
      </HeadingWithAnchor>
      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-300 mb-6">
        <li>
          <strong>PII protection</strong> - Email addresses and other PII are automatically filtered
        </li>
        <li>
          <strong>Retention compliance</strong> - Filtered logs can be retained longer without
          privacy concerns
        </li>
        <li>
          <strong>Data minimization</strong> - Only necessary debugging metadata is preserved
        </li>
      </ul>

      <HeadingWithAnchor id="getting-started" level={2}>
        Getting Started
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct&apos;s security features work out of the box with zero configuration. For more
        details on customizing filtering rules, see:
      </p>

      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-300 mb-6">
        <li>
          <a
            href="/docs/filtering-sensitive-data"
            className="text-blue-600 dark:text-blue-400 hover:underline"
          >
            Filtering Sensitive Data
          </a>{' '}
          - Comprehensive guide to filtering configuration
        </li>
        <li>
          <a href="/docs/sorbet-types" className="text-blue-600 dark:text-blue-400 hover:underline">
            Sorbet Types
          </a>{' '}
          - Learn more about type safety in logs
        </li>
        <li>
          <a
            href="/docs/configuration"
            className="text-blue-600 dark:text-blue-400 hover:underline"
          >
            Configuration
          </a>{' '}
          - General configuration options
        </li>
      </ul>

      <Callout type="info">
        <strong>Need help with SOC 2?</strong> LogStruct is used by companies undergoing SOC 2
        audits. If you have any questions or concerns about compliance, please{' '}
        <a
          href="https://github.com/DocSpring/logstruct/issues"
          className="text-blue-600 dark:text-blue-400 hover:underline"
        >
          reach out on GitHub
        </a>
        .
      </Callout>

      <EditPageLink />
    </div>
  );
}
