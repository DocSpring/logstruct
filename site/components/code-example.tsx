'use client';

import React from 'react';
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { atomDark } from 'react-syntax-highlighter/dist/esm/styles/prism';

interface CodeExampleProps {
  code: string;
  language?: string;
  showLineNumbers?: boolean;
  highlightLines?: number[];
  title?: string;
}

/**
 * Component to display a code example with syntax highlighting
 * The code should be passed in directly from getCodeExample() in server components
 * or via getStaticProps for static site generation
 */
export function CodeExample({
  code,
  language = 'ruby',
  showLineNumbers = true,
  highlightLines = [],
  title
}: CodeExampleProps) {
  if (!code) {
    return (
      <div className="p-4 bg-yellow-100 text-yellow-800 rounded-md">
        <p>No code provided</p>
      </div>
    );
  }
  
  return (
    <div className="my-6">
      {title && (
        <div className="font-medium text-sm mb-2 text-gray-700">
          {title}
        </div>
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
              return { style: { ...style, backgroundColor: 'rgba(255, 255, 255, 0.1)' } };
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
          {code}
        </SyntaxHighlighter>
      </div>
    </div>
  );
}