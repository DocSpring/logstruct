"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";

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
        "block py-2 px-4 rounded-md hover:bg-neutral-100 dark:hover:bg-neutral-800 transition-colors",
        active && "bg-neutral-100 dark:bg-neutral-800 font-medium"
      )}
    >
      {title}
    </Link>
  );
}

export default function DocsLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  
  return (
    <div className="flex min-h-screen flex-col">
      <div className="container mx-auto flex-1 px-4 py-8 md:py-12">
        <div className="flex flex-col gap-10 lg:flex-row">
          {/* Sidebar */}
          <aside className="w-full lg:w-64 xl:w-72 shrink-0">
            <div className="sticky top-24">
              <div className="p-1 space-y-1">
                <h2 className="mb-3 text-lg font-semibold">Documentation</h2>
                <nav className="space-y-1">
                  <DocNavItem 
                    href="/docs" 
                    title="Introduction" 
                    active={pathname === "/docs"} 
                  />
                  <DocNavItem 
                    href="/docs/getting-started" 
                    title="Getting Started" 
                    active={pathname === "/docs/getting-started"} 
                  />
                  <DocNavItem 
                    href="/docs/configuration" 
                    title="Configuration" 
                    active={pathname === "/docs/configuration"} 
                  />
                  <DocNavItem 
                    href="/docs/integrations" 
                    title="Integrations" 
                    active={pathname === "/docs/integrations"} 
                  />
                  <DocNavItem 
                    href="/docs/type-safety" 
                    title="Type Safety" 
                    active={pathname === "/docs/type-safety"} 
                  />
                </nav>
                
                <h2 className="mt-6 mb-3 text-lg font-semibold">API Reference</h2>
                <nav className="space-y-1">
                  <DocNavItem 
                    href="#" 
                    title="YARD Documentation" 
                    active={false} 
                  />
                  <DocNavItem 
                    href="#" 
                    title="Code Coverage" 
                    active={false} 
                  />
                </nav>
              </div>
            </div>
          </aside>
          
          {/* Main content */}
          <main className="flex-1 min-w-0">
            <div className="max-w-3xl mx-auto">
              {children}
            </div>
          </main>
        </div>
      </div>
    </div>
  );
}