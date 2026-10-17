import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';

// The misspelled event in the provider's error message
// cspell:ignore deliverd

export const metadata = {
  title: 'Terraform Provider',
  description:
    'Use the DocSpring/logstruct Terraform provider to build CloudWatch filter patterns for LogStruct log lines, checked against the sources and events LogStruct writes.',
};

const pClass = 'text-neutral-600 dark:text-neutral-300';
const listClass = 'list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300';

const requiredProviders = `terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    logstruct = {
      source  = "DocSpring/logstruct"
      version = "~> 0.2.0"
    }
  }
}`;

function metricFilterModule(
  label: string,
  name: string,
  logSource: string,
  logEvent: string,
): string {
  return `module "${label}" {
  source  = "DocSpring/logstruct/aws//modules/metric-filter"
  version = "~> 0.1.0"

  name           = "${name}"
  log_group_name = var.log_group_name
  log_source     = "${logSource}"
  log_event      = "${logEvent}"
  namespace      = var.namespace
}`;
}

const emailDelivered = metricFilterModule(
  'email_delivered_count',
  'Email Delivered Count',
  'mailer',
  'delivered',
);
const mailerErrors = metricFilterModule(
  'mailer_error_count',
  'Mailer Error Count',
  'mailer',
  'error',
);
const jobFinish = metricFilterModule('job_finish_count', 'ActiveJob Finish Count', 'job', 'finish');
const slowSql = metricFilterModule('slow_sql_count', 'Slow SQL Query Count', 'app', 'database');

const providerDataSources = `data "logstruct_source" "mailer" {
  source = "mailer"
}

data "logstruct_pattern" "email_delivered" {
  source = data.logstruct_source.mailer.canonical
  event  = "delivered"
}

resource "aws_cloudwatch_log_metric_filter" "email_delivered" {
  name           = "Email Delivered Count"
  log_group_name = var.log_group_name
  pattern        = data.logstruct_pattern.email_delivered.pattern

  metric_transformation {
    name      = "mailer_delivered"
    namespace = var.namespace
    value     = "1"
    unit      = "Count"
  }
}`;

const numericPattern = `resource "aws_cloudwatch_log_metric_filter" "very_slow_sql" {
  name           = "Very Slow SQL Query Count"
  log_group_name = var.log_group_name
  pattern        = "{ $.src = \\"app\\" && $.evt = \\"database\\" && $.duration_ms > 1000 }"

  metric_transformation {
    name      = "sql_very_slow"
    namespace = var.namespace
    value     = "1"
    unit      = "Count"
  }
}`;

export default function TerraformDocsPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="terraform-provider" level={1}>
        Terraform Provider
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-300">
        The LogStruct Terraform provider builds CloudWatch Logs filter patterns for LogStruct&apos;s
        log lines from a source (<code>src</code>) and an event (<code>evt</code>). The plan fails
        if no LogStruct line has that source and event, so a typo or a removed event is caught
        before anything is deployed.
      </p>

      <HeadingWithAnchor id="installation">Installation</HeadingWithAnchor>
      <p className={pClass}>
        Add the provider to <code>required_providers</code>. It has no settings, so it needs no{' '}
        <code>provider</code> block.
      </p>
      <CodeBlock language="hcl" title="versions.tf">
        {requiredProviders}
      </CodeBlock>
      <p className={pClass}>
        The AWS provider is only needed for the module below, which creates an{' '}
        <code>aws_cloudwatch_log_metric_filter</code>. The module asks for the LogStruct provider{' '}
        <code>&gt;= 0.1.0</code>, so your constraint above decides the version.
      </p>

      <HeadingWithAnchor id="example">CloudWatch Metric Filter</HeadingWithAnchor>
      <p className={pClass}>
        The <code>metric-filter</code> module counts the lines with a source and an event: each
        matching line adds 1 to the metric. Its inputs are <code>name</code>,{' '}
        <code>log_group_name</code>, <code>log_source</code>, <code>log_event</code>,{' '}
        <code>namespace</code> and an optional <code>metric_name</code> (by default{' '}
        <code>&lt;log_source&gt;_&lt;log_event&gt;</code>, here <code>mailer_delivered</code>). It
        outputs the <code>pattern</code> it used.
      </p>
      <CodeBlock language="hcl" title="Module: Metric Filter">
        {emailDelivered}
      </CodeBlock>
      <CodeBlock language="hcl" title="Variables">
        {`variable "log_group_name" { type = string }
variable "namespace" { type = string }`}
      </CodeBlock>

      <HeadingWithAnchor id="validation">What the Provider Checks</HeadingWithAnchor>
      <ul className={listClass}>
        <li>
          The provider has a catalog of LogStruct&apos;s sources and the events each one writes,
          compiled into the provider. Each provider release is built from the LogStruct release with
          the same version number.
        </li>
        <li>
          It never looks at your app or the gem version your app runs. Upgrading the gem changes
          nothing in Terraform; a plan can only start failing when you upgrade the provider and your
          source and event are no longer in its catalog.
        </li>
        <li>
          An unknown source or event fails the plan:
          <CodeBlock language="text">
            {`Error: Invalid event
event deliverd is not allowed for source mailer

Error: Unknown source
No structs found with fixed source = payments`}
          </CodeBlock>
        </li>
        <li>
          The pattern matches <code>src</code> and <code>evt</code> only, for example{' '}
          <code>{'{ $.evt = "delivered" && $.src = "mailer" }'}</code>. Lines from different
          integrations with the same source and event match the same pattern: ActiveJob&apos;s and
          GoodJob&apos;s error lines both have <code>src: &quot;job&quot;</code> and{' '}
          <code>evt: &quot;error&quot;</code>.
        </li>
        <li>
          The catalog only has sources with a fixed set of events, so it has no pattern for the
          general error lines (such as <code>src: &quot;app&quot;</code>,{' '}
          <code>evt: &quot;error&quot;</code>) or for your own{' '}
          <a href="/docs/sorbet-types#custom-log-classes">custom log types</a>. Write those patterns
          yourself, as in the last recipe below.
        </li>
      </ul>

      <HeadingWithAnchor id="versioning">Versioning</HeadingWithAnchor>
      <ul className={listClass}>
        <li>
          Provider versions match LogStruct&apos;s: provider <code>0.2.0</code> has the sources and
          events of LogStruct <code>0.2.0</code>.
        </li>
        <li>
          Use <code>~&gt; 0.2.0</code> to get <code>0.2.x</code> releases only. Below 1.0,{' '}
          <code>~&gt; 0.2</code> also allows <code>0.3</code> and later, and a minor release can
          remove events: <code>0.2.0</code> removed GoodJob&apos;s <code>enqueue</code>,{' '}
          <code>start</code>, <code>finish</code> and <code>schedule</code>, which GoodJob never
          wrote (its jobs&apos; lines come from ActiveJob, with the same source and events).
        </li>
      </ul>

      <HeadingWithAnchor id="recipes">Recipes</HeadingWithAnchor>

      <HeadingWithAnchor id="count-email-deliveries" level={3}>
        Count email deliveries
      </HeadingWithAnchor>
      <CodeBlock language="hcl">{emailDelivered}</CodeBlock>

      <HeadingWithAnchor id="count-mailer-errors" level={3}>
        Count mailer errors
      </HeadingWithAnchor>
      <p className={pClass}>
        LogStruct writes a mailer <code>error</code> line when a mailer raises an error, as when a
        delivery fails.
      </p>
      <CodeBlock language="hcl">{mailerErrors}</CodeBlock>

      <HeadingWithAnchor id="count-activejob-runs" level={3}>
        Count finished ActiveJob runs
      </HeadingWithAnchor>
      <p className={pClass}>
        ActiveJob writes a <code>finish</code> line when a job&apos;s <code>perform</code> returns.
        That includes a run whose exception <code>retry_on</code> or <code>discard_on</code>{' '}
        handled, which also has a <code>retry</code> or <code>discard</code> line. A run that raises
        has an <code>error</code> line instead.
      </p>
      <CodeBlock language="hcl">{jobFinish}</CodeBlock>

      <HeadingWithAnchor id="count-slow-sql-queries" level={3}>
        Count slow SQL queries
      </HeadingWithAnchor>
      <p className={pClass}>
        SQL lines are off by default (<code>enable_sql_logging</code>). When they&apos;re on,
        LogStruct writes one for each query that takes at least{' '}
        <code>sql_slow_query_threshold</code> milliseconds (100 by default).
      </p>
      <CodeBlock language="hcl">{slowSql}</CodeBlock>

      <HeadingWithAnchor id="provider-data-sources" level={3}>
        Use the data sources directly
      </HeadingWithAnchor>
      <p className={pClass}>
        The module uses the provider&apos;s two data sources. <code>logstruct_pattern</code> takes a{' '}
        <code>source</code> and an <code>event</code> and returns the <code>pattern</code>.{' '}
        <code>logstruct_source</code> takes a <code>source</code> and returns it as{' '}
        <code>canonical</code>, with the source&apos;s <code>events</code> as a map. Use them to
        build your own metric filters or subscription filters:
      </p>
      <CodeBlock language="hcl">{providerDataSources}</CodeBlock>

      <HeadingWithAnchor id="numeric-comparisons" level={3}>
        Match on other fields
      </HeadingWithAnchor>
      <p className={pClass}>
        CloudWatch&apos;s JSON filter patterns can compare numbers, but the provider only builds{' '}
        <code>src</code> and <code>evt</code> patterns. Write a pattern with other fields yourself:
      </p>
      <CodeBlock language="hcl">{numericPattern}</CodeBlock>
      <p className={pClass}>
        To chart the durations instead of counting the lines, set <code>value</code> to{' '}
        <code>&quot;$.duration_ms&quot;</code>.
      </p>

      <HeadingWithAnchor id="links">Links</HeadingWithAnchor>
      <ul className={listClass}>
        <li>
          <a
            href="https://registry.terraform.io/providers/DocSpring/logstruct/latest"
            target="_blank"
            rel="noopener noreferrer"
          >
            Provider (Terraform Registry)
          </a>
        </li>
        <li>
          <a
            href="https://registry.terraform.io/modules/DocSpring/logstruct/aws"
            target="_blank"
            rel="noopener noreferrer"
          >
            AWS module (Terraform Registry)
          </a>
        </li>
        <li>
          <a
            href="https://github.com/DocSpring/terraform-provider-logstruct"
            target="_blank"
            rel="noopener noreferrer"
          >
            Provider source (GitHub)
          </a>
        </li>
      </ul>

      <EditPageLink />
    </div>
  );
}
