'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

interface EditPageLinkProps {
  path?: string;
}

export function EditPageLink({ path }: EditPageLinkProps) {
  const pathname = usePathname();

  // Allow overriding the path or derive it from the pathname
  const derivedPath =
    path ??
    // Convert the path to a GitHub file path
    // For /docs/getting-started, the file is at docs/app/docs/getting-started/page.tsx
    // Handle special case for root paths to avoid double slashes
    (pathname === '/' ? '/docs/app/page.tsx' : `/docs/app${pathname}/page.tsx`);

  // Ensure there are no double slashes in the path
  const normalizedPath = derivedPath.replace(/\/\//g, '/');

  const githubEditUrl = `https://github.com/DocSpring/logstruct/edit/main${normalizedPath}`;

  return (
    <div className="mt-16 pt-4 border-t border-neutral-200 dark:border-neutral-800">
      <Link
        href={githubEditUrl}
        target="_blank"
        rel="noopener noreferrer"
        className="text-sm text-neutral-500 hover:text-neutral-900 dark:text-neutral-300 dark:hover:text-neutral-100 flex items-center"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
          className="mr-2"
        >
          <path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"></path>
          <path d="m15 5 4 4"></path>
        </svg>
        Edit this page on GitHub
      </Link>
    </div>
  );
}
