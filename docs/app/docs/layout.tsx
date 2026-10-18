'use client';

import { ChevronDown } from 'lucide-react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useState } from 'react';
import { NestedDocNavItem } from '@/components/nested-doc-nav-item';
import { AllLogTypes } from '@/generated/logstruct';
import { getLogTypeInfo, getTitleId } from '@/lib/integration-helpers';
import { cn } from '@/lib/utils';

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

export default function DocsLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  // Below lg the sidebar sits above the page, so it's a menu that opens on the page it was opened on
  const [menuOpenOn, setMenuOpenOn] = useState<string | null>(null);
  const menuOpen = menuOpenOn === pathname;

  // Build Integrations subheadings from log types (plus Sorbet special case). An integration with
  // a page of its own links to it.
  const integrationHeadings = [
    ...(AllLogTypes.map((logType) => {
      const info = getLogTypeInfo(logType);
      if (!info) return null;
      const { title, docsPath } = info;
      const id = getTitleId(title);
      return {
        id,
        title,
        href: docsPath?.startsWith('/docs/integrations/') ? docsPath : undefined,
      };
    }).filter(Boolean) as Array<{ id: string; title: string; href?: string }>),
    // Sorbet Integration (special case section on the page)
    { id: 'sorbet-integration', title: 'Sorbet Integration' },
  ];

  return (
    <div className="flex min-h-screen flex-col">
      <div className="container mx-auto flex-1 px-4 py-8 md:py-12">
        <div className="flex flex-col gap-10 lg:flex-row">
          {/* Sidebar */}
          <aside className="w-full lg:w-64 xl:w-72 shrink-0">
            <button
              type="button"
              className="lg:hidden flex w-full items-center justify-between rounded-md border border-neutral-200 dark:border-neutral-800 px-4 py-2 font-medium cursor-pointer"
              aria-expanded={menuOpen}
              aria-controls="docs-sidebar"
              onClick={() => setMenuOpenOn(menuOpen ? null : pathname)}
            >
              Documentation menu
              <ChevronDown
                className={cn('w-4 h-4 transition-transform', menuOpen && 'rotate-180')}
              />
            </button>
            <div
              id="docs-sidebar"
              className={cn(
                'pr-2 pb-10 lg:block lg:sticky lg:top-24 lg:overflow-y-auto lg:max-h-[calc(100vh-8rem)]',
                menuOpen ? 'block mt-4' : 'hidden',
              )}
            >
              <div className="p-1 space-y-1">
                <h2 className="mb-3 text-lg font-semibold">Documentation</h2>
                <nav className="space-y-1">
                  <DocNavItem
                    href="/docs"
                    title="Introduction"
                    active={pathname === '/docs' || pathname === '/docs/'}
                  />
                  <DocNavItem
                    href="/docs/getting-started"
                    title="Getting Started"
                    active={pathname.startsWith('/docs/getting-started')}
                  />
                  <NestedDocNavItem
                    href="/docs/configuration"
                    title="Configuration"
                    active={pathname.startsWith('/docs/configuration')}
                    subHeadings={[
                      { id: 'enabling-logstruct', title: 'Enabling LogStruct' },
                      { id: 'environment-configuration', title: 'Environment Configuration' },
                      { id: 'development-preview', title: 'Logger Settings' },
                      { id: 'integration-configuration', title: 'Integration Configuration' },
                      { id: 'filtering-sensitive-data', title: 'Filtering Sensitive Data' },
                      { id: 'limits', title: 'Limits' },
                      { id: 'error-handling-configuration', title: 'Error Handling' },
                      { id: 'actionmailer-id-mapping', title: 'ActionMailer ID Mapping' },
                      { id: 'custom-lograge-options', title: 'Custom Lograge Options' },
                      { id: 'custom-string-scrubbing', title: 'Custom String Scrubbing' },
                      { id: 'custom-error-reporting', title: 'Custom Error Reporting' },
                      { id: 'sorbet-integration', title: 'Sorbet Integration' },
                    ]}
                  />
                  <DocNavItem
                    href="/docs/when-logstruct-runs"
                    title="When LogStruct Runs"
                    active={pathname.startsWith('/docs/when-logstruct-runs')}
                  />
                  <NestedDocNavItem
                    href="/docs/integrations"
                    title="Integrations"
                    active={pathname.startsWith('/docs/integrations')}
                    subHeadings={integrationHeadings}
                  />
                  <DocNavItem
                    href="/docs/log-fields"
                    title="Log Fields"
                    active={pathname.startsWith('/docs/log-fields')}
                  />
                  <DocNavItem
                    href="/docs/logging"
                    title="Logging (12‑Factor)"
                    active={pathname.startsWith('/docs/logging')}
                  />
                  <NestedDocNavItem
                    href="/docs/filtering-sensitive-data"
                    title="Filtering Sensitive Data"
                    active={pathname.startsWith('/docs/filtering-sensitive-data')}
                    subHeadings={[
                      { id: 'key-filtering', title: 'Filtering by Key' },
                      { id: 'string-scrubbing', title: 'String Scrubbing' },
                      { id: 'where-filtering-applies', title: 'Where Filtering Applies' },
                      { id: 'large-values', title: 'Large and Nested Values' },
                    ]}
                  />
                  <NestedDocNavItem
                    href="/docs/sorbet-types"
                    title="Sorbet Types"
                    active={pathname.startsWith('/docs/sorbet-types')}
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
                    href="/docs/comparison"
                    title="Comparison with Other Gems"
                    active={pathname.startsWith('/docs/comparison')}
                  />
                  <DocNavItem
                    href="/docs/terraform"
                    title="Terraform Provider"
                    active={pathname.startsWith('/docs/terraform')}
                  />
                  <DocNavItem
                    href="/docs/supported-versions"
                    title="Supported Versions"
                    active={pathname.startsWith('/docs/supported-versions')}
                  />
                  <DocNavItem
                    href="/docs/upgrading"
                    title="Upgrading to 0.2.0"
                    active={pathname.startsWith('/docs/upgrading')}
                  />
                  <DocNavItem
                    href="/docs/troubleshooting"
                    title="Troubleshooting"
                    active={pathname.startsWith('/docs/troubleshooting')}
                  />
                  <DocNavItem
                    href="/docs/companies"
                    title="Companies Using LogStruct"
                    active={pathname.startsWith('/docs/companies')}
                  />
                </nav>

                <h2 className="mt-6 mb-3 text-lg font-semibold">Guides</h2>
                <nav className="space-y-1">
                  <NestedDocNavItem
                    href="/docs/soc2-compliance"
                    title="SOC 2 and Your Logs"
                    active={pathname.startsWith('/docs/soc2-compliance')}
                    subHeadings={[
                      { id: 'what-logstruct-does', title: 'What LogStruct Does' },
                      { id: 'where-it-stops', title: 'Where It Stops' },
                      { id: 'what-your-app-does', title: 'What Your App Still Has to Do' },
                    ]}
                  />
                  <DocNavItem
                    href="/docs/guides/postmark-error-handling"
                    title="Handling Postmark Errors"
                    active={pathname.startsWith('/docs/guides/postmark-error-handling')}
                  />
                </nav>

                <h2 className="mt-6 mb-3 text-lg font-semibold">Reference</h2>
                <nav className="space-y-1">
                  <DocNavItem href="/yard/index.html" title="YARD Documentation" active={false} />
                  <DocNavItem href="/coverage/index.html" title="Code Coverage" active={false} />
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
