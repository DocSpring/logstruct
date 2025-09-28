'use client';

import Link from 'next/link';

export function EmptyNav() {
  return (
    <div className="mr-4 flex w-full items-center justify-between">
      <div className="flex items-end space-x-2">
        <Link href="/" className="font-bold text-xl leading-none">
          LogStruct
        </Link>
        <a
          href="https://docspring.com"
          target="_blank"
          rel="noopener noreferrer"
          className="text-xs text-neutral-500 hover:text-neutral-700 dark:hover:text-neutral-300"
        >
          by DocSpring
        </a>
      </div>
    </div>
  );
}
