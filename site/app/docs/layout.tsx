'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { cn } from '@/lib/utils';
import { NestedDocNavItem } from '@/components/nested-doc-nav-item';
import { AllLogTypes } from '@/generated/logstruct';
import { getLogTypeInfo, getTitleId } from '@/lib/integration-helpers';

interface DocNavItemProps {
  href: string;
  title: string;
  active?: boolean;
}

function DocNavItem({ href, title, active }: DocNavItemProps) {
  return (
    <Link
      href={href}
      className={cn(
        'block py-2 px-4 rounded-md hover:bg-neutral-100 dark:hover:bg-neutral-800 transition-colors',
        active && 'bg-neutral-100 dark:bg-neutral-800 font-medium',
      )}
    >
      {title}
    </Link>
  );
}

export default function DocsLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const pathname = usePathname();

  // Build Integrations subheadings from log types (plus Sorbet special case)
  const integrationHeadings = [
    // Dynamic entries from all log types
    ...(AllLogTypes.map((logType) => {
      const info = getLogTypeInfo(logType);
      if (!info) return null;
      const { title } = info;
      const id = getTitleId(title);
      return { id, title };
    }).filter(Boolean) as Array<{ id: string; title: string }>),
    // Sorbet Integration (special case section on the page)
    { id: 'sorbet-integration', title: 'Sorbet Integration' },
  ];

  return (
    <div className="flex min-h-screen flex-col">
      <div className="container mx-auto flex-1 px-4 py-8 md:py-12">
        <div className="flex flex-col gap-10 lg:flex-row">
          {/* Sidebar */}
          <aside className="w-full lg:w-64 xl:w-72 shrink-0">
            <div className="sticky top-24 overflow-y-auto max-h-[calc(100vh-8rem)] pr-2 pb-10">
              <div className="p-1 space-y-1">
                <h2 className="mb-3 text-lg font-semibold">Documentation</h2>
                <nav className="space-y-1">
                  <DocNavItem
                    href="/docs"
                    title="Introduction"
                    active={pathname === '/docs' || pathname === '/site/'}
                  />
                  <DocNavItem
                    href="/site/getting-started"
                    title="Getting Started"
                    active={pathname.startsWith('/site/getting-started')}
                  />
                  <NestedDocNavItem
                    href="/site/configuration"
                    title="Configuration"
                    active={pathname.startsWith('/site/configuration')}
                    subHeadings={[
                      {
                        id: 'enabling-logstruct',
                        title: 'Enabling LogStruct',
                      },
                      {
                        id: 'environment-configuration',
                        title: 'Environment Configuration',
                      },
                      {
                        id: 'integration-configuration',
                        title: 'Integration Configuration',
                      },
                      {
                        id: 'filtering-sensitive-data',
                        title: 'Filtering Sensitive Data',
                      },
                      {
                        id: 'error-handling-configuration',
                        title: 'Error Handling',
                      },
                      {
                        id: 'custom-lograge-options',
                        title: 'Custom Lograge Options',
                      },
                      {
                        id: 'custom-string-scrubbing',
                        title: 'Custom String Scrubbing',
                      },
                      {
                        id: 'custom-error-reporting',
                        title: 'Custom Error Reporting',
                      },
                      { id: 'sorbet-integration', title: 'Sorbet Integration' },
                    ]}
                  />
                  <NestedDocNavItem
                    href="/site/integrations"
                    title="Integrations"
                    active={pathname.startsWith('/site/integrations')}
                    subHeadings={integrationHeadings}
                  />
                  <DocNavItem
                    href="/site/logging"
                    title="Logging (12‑Factor)"
                    active={pathname.startsWith('/site/logging')}
                  />
                  <NestedDocNavItem
                    href="/site/filtering-sensitive-data"
                    title="Filtering Sensitive Data"
                    active={pathname.startsWith(
                      '/site/filtering-sensitive-data',
                    )}
                    subHeadings={[
                      {
                        id: 'parameter-filtering',
                        title: 'Parameter Filtering',
                      },
                      {
                        id: 'string-scrubbing',
                        title: 'String Scrubbing',
                      },
                      {
                        id: 'examples',
                        title: 'Examples',
                      },
                    ]}
                  />
                  <NestedDocNavItem
                    href="/site/sorbet-types"
                    title="Sorbet Types"
                    active={pathname.startsWith('/site/sorbet-types')}
                    subHeadings={[
                      {
                        id: 'what-is-sorbet',
                        title: 'What is Sorbet?',
                      },
                      {
                        id: 'adding-sorbet',
                        title: 'Adding Sorbet to Your Application',
                      },
                      {
                        id: 'using-logstruct-with-sorbet',
                        title: 'Using LogStruct with Sorbet',
                      },
                      {
                        id: 'error-handling',
                        title: 'Error Handling for Type Errors',
                      },
                      {
                        id: 'custom-log-classes',
                        title: 'Custom Typed Logs',
                      },
                      {
                        id: 'builtin-log-classes',
                        title: 'Built-In Log Classes',
                      },
                      {
                        id: 'built-in-enums',
                        title: 'Built-In Enums',
                      },
                    ]}
                  />

                  <DocNavItem
                    href="/site/comparison"
                    title="Comparison with Other Gems"
                    active={pathname.startsWith('/site/comparison')}
                  />
                  <DocNavItem
                    href="/site/terraform"
                    title="Terraform Provider"
                    active={pathname.startsWith('/site/terraform')}
                  />
                  <DocNavItem
                    href="/site/supported-versions"
                    title="Supported Versions"
                    active={pathname.startsWith('/site/supported-versions')}
                  />
                  <DocNavItem
                    href="/site/companies"
                    title="Companies Using LogStruct"
                    active={pathname.startsWith('/site/companies')}
                  />
                </nav>

                <h2 className="mt-6 mb-3 text-lg font-semibold">Reference</h2>
                <nav className="space-y-1">
                  <DocNavItem
                    href="/yard/index.html"
                    title="YARD Documentation"
                    active={false}
                  />
                  <DocNavItem
                    href="/coverage/index.html"
                    title="Code Coverage"
                    active={false}
                  />
                </nav>
              </div>
            </div>
          </aside>

          {/* Main content */}
          <main className="flex-1 min-w-0">
            <div className="max-w-3xl mx-auto docs-content">{children}</div>
          </main>
        </div>
      </div>
    </div>
  );
}
