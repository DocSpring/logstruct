'use client';

import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { atomDark } from 'react-syntax-highlighter/dist/esm/styles/prism';

// Custom code theme based on atomDark but with better Ruby module styling
const customTheme = {
  ...atomDark,
  namespace: {
    color: '#81a2be', // Softer blue instead of yellow
    fontStyle: 'normal', // Remove italics
    textDecoration: 'none', // Remove underline
  },
  'entity.name.module': {
    color: '#81a2be', // Match the namespace color
    fontStyle: 'normal',
    textDecoration: 'none',
  },
  'class-name': {
    color: '#de935f', // More vibrant orange for class names
    fontStyle: 'normal',
  },
  constant: {
    color: '#81a2be', // Same blue for constants
    fontWeight: 'normal',
  },
};

interface CodeBlockProps {
  children: string | string[];
  language?: string;
  showLineNumbers?: boolean;
  highlightLines?: number[];
  title?: string;
  unwrapped?: boolean; // Used for TabsContent to avoid double wrapping
}

/**
 * Base component for displaying code with syntax highlighting
 * Used by both RubyCodeExample and for static code examples
 */
export function CodeBlock({
  children,
  language = 'ruby',
  showLineNumbers = false,
  highlightLines = [],
  title,
  unwrapped = false,
}: CodeBlockProps) {
  if (!children) {
    throw new Error('No code provided to CodeBlock component!');
  }

  // Common highlighter settings
  const highlighter = (
    <SyntaxHighlighter
      language={language}
      style={customTheme}
      showLineNumbers={showLineNumbers}
      wrapLines={true}
      lineProps={(lineNumber) => {
        const style = { display: 'block', width: '100%' };
        if (highlightLines.includes(lineNumber)) {
          return {
            style: {
              ...style,
              backgroundColor: 'rgba(255, 255, 255, 0.1)',
            },
          };
        }
        return { style };
      }}
      customStyle={{
        margin: 0,
        padding: unwrapped ? '0' : '1rem',
        fontSize: '0.9rem',
        borderRadius: unwrapped ? '0' : '0.5rem',
        backgroundColor: unwrapped ? 'transparent' : '#1d1f21', // Explicit dark background
      }}
    >
      {children}
    </SyntaxHighlighter>
  );

  // If unwrapped, return just the highlighter without any container divs
  if (unwrapped) {
    return highlighter;
  }

  // Regular wrapped version
  return (
    <div>
      {title && <div className="font-medium text-sm mb-2 text-gray-700">{title}</div>}
      <div className="overflow-hidden rounded-lg">{highlighter}</div>
    </div>
  );
}
