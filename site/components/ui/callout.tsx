import React from 'react';
import { cn } from '@/lib/utils';

interface CalloutProps {
  children: React.ReactNode;
  type?: 'info' | 'warning' | 'success';
  className?: string;
}

export function Callout({
  children,
  type = 'info',
  className,
}: CalloutProps) {
  const typeStyles = {
    info: 'bg-blue-50 text-blue-800 dark:bg-blue-950/30 dark:text-blue-300 border-blue-200 dark:border-blue-800/50',
    warning: 'bg-yellow-50 text-yellow-800 dark:bg-yellow-950/30 dark:text-yellow-300 border-yellow-200 dark:border-yellow-800/50',
    success: 'bg-green-50 text-green-800 dark:bg-green-950/30 dark:text-green-300 border-green-200 dark:border-green-800/50',
  };

  return (
    <div
      className={cn(
        'p-4 rounded-md border-l-4',
        typeStyles[type],
        className
      )}
    >
      {children}
    </div>
  );
}