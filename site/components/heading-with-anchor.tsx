import { LinkIcon } from 'lucide-react';
import Link from 'next/link';

// Header component with an anchor link that shows on hover
export function HeadingWithAnchor({
  id,
  level = 2,
  className = '',
  children,
}: {
  id: string;
  level?: number;
  className?: string;
  children: React.ReactNode;
}) {
  const baseClasses =
    level === 1 ? 'text-4xl font-bold' : 'text-2xl font-bold mt-10 mb-4';

  // Add scroll-margin-top to ensure the heading isn't hidden behind the navbar when scrolled to
  const combinedClasses =
    `group ${baseClasses} ${className} scroll-mt-20`.trim();
  const Component = `h${level}` as keyof JSX.IntrinsicElements;

  return (
    <Component id={id} className={combinedClasses}>
      {children}
      <Link
        href={`#${id}`}
        className="ml-2 opacity-0 group-hover:opacity-100 transition-opacity"
        aria-label={`Link to ${children}`}
      >
        <LinkIcon className="inline h-5 w-5 text-neutral-400 hover:text-neutral-700 dark:hover:text-neutral-300" />
      </Link>
    </Component>
  );
}
