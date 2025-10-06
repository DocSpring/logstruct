'use client';

import { ChevronDown, ChevronRight } from 'lucide-react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect, useRef, useState } from 'react';
import { cn } from '@/lib/utils';

interface SubHeading {
  id: string;
  title: string;
}

interface NestedDocNavItemProps {
  href: string;
  title: string;
  subHeadings?: SubHeading[];
  active?: boolean;
}

export function NestedDocNavItem({ href, title, subHeadings = [], active }: NestedDocNavItemProps) {
  const pathname = usePathname();
  const [isOpen, setIsOpen] = useState(active || pathname.startsWith(href));
  const hasSubHeadings = subHeadings.length > 0;

  // Check if this item or any of its subheadings are active
  const isActiveRoute = pathname.startsWith(href);

  // Track previous active state to detect navigation
  const previousPathname = useRef(pathname);

  // Handle navigation-based state changes
  useEffect(() => {
    const isNavigatingToThisRoute =
      pathname.startsWith(href) && !previousPathname.current.startsWith(href);

    // Auto-expand only when navigating TO this route from elsewhere
    if (isNavigatingToThisRoute && hasSubHeadings) {
      setIsOpen(true);
    }

    // Update the previous pathname
    previousPathname.current = pathname;
  }, [pathname, href, hasSubHeadings]);

  // Toggle function for arrows and active title clicks
  const toggleOpen = (e: React.MouseEvent) => {
    e.stopPropagation();
    e.preventDefault();
    setIsOpen(!isOpen);
  };

  return (
    <div className="relative">
      <div
        className={cn(
          'flex items-center justify-between py-2 px-4 rounded-md hover:bg-neutral-100 dark:hover:bg-neutral-800 transition-colors',
          isActiveRoute && 'bg-neutral-100 dark:bg-neutral-800 font-medium',
        )}
      >
        {/* Title link - normal navigation or toggle if already active */}
        <Link
          href={href}
          className="flex-grow"
          onClick={(e) => {
            // Only toggle if already on this route
            if (isActiveRoute && hasSubHeadings) {
              toggleOpen(e);
            }
          }}
        >
          {title}
        </Link>

        {/* Arrow button - always toggles expand/collapse */}
        {hasSubHeadings && (
          <button
            type="button"
            className="ml-2 flex items-center justify-center focus:outline-none"
            onClick={toggleOpen}
            aria-label={isOpen ? 'Collapse section' : 'Expand section'}
          >
            {isOpen ? (
              <ChevronDown className="h-4 w-4 text-neutral-500 transition-transform duration-200" />
            ) : (
              <ChevronRight className="h-4 w-4 text-neutral-500 transition-transform duration-200" />
            )}
          </button>
        )}
      </div>

      {/* Subheadings with animation */}
      {hasSubHeadings && (
        <div
          className={cn(
            'pl-4 space-y-0.5 overflow-hidden transition-all duration-300 ease-in-out',
            isOpen ? 'max-h-96 opacity-100 mt-1' : 'max-h-0 opacity-0',
          )}
        >
          {subHeadings.map((subHeading) => {
            const subHeadingHref = `${href}#${subHeading.id}`;
            // Check if this specific subheading is active
            const isSubheadingActive =
              pathname.startsWith(href) && pathname.includes(`#${subHeading.id}`);

            return (
              <Link
                key={subHeading.id}
                href={subHeadingHref}
                className={cn(
                  'block py-1 px-4 text-sm rounded-md hover:bg-neutral-100 dark:hover:bg-neutral-800 transition-colors',
                  isSubheadingActive && 'bg-neutral-100 dark:bg-neutral-800 font-medium',
                )}
              >
                {subHeading.title}
              </Link>
            );
          })}
        </div>
      )}
    </div>
  );
}
