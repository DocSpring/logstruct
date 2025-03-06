'use client';

import React from 'react';
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { atomDark } from 'react-syntax-highlighter/dist/esm/styles/prism';

interface CodeBlockProps {
  children: string | string[];
  language?: string;
  showLineNumbers?: boolean;
  highlightLines?: number[];
  title?: string;
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
}: CodeBlockProps) {
  if (!children) {
    throw new Error('No code provided to CodeBlock component!');
  }

  return (
    <div className="my-6">
      {title && (
        <div className="font-medium text-sm mb-2 text-gray-700">{title}</div>
      )}
      <div className="overflow-hidden rounded-lg">
        <SyntaxHighlighter
          language={language}
          style={atomDark}
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
            padding: '1rem',
            fontSize: '0.9rem',
            borderRadius: '0.5rem',
          }}
        >
          {children}
        </SyntaxHighlighter>
      </div>
    </div>
  );
}
