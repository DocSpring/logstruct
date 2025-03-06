// Server Component - used at build time for static generation
import React from 'react';
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { atomDark } from 'react-syntax-highlighter/dist/esm/styles/prism';
import { getCodeExample } from '@/lib/codeExamples';

export interface RubyCodeExampleProps {
  name: string;
  showLineNumbers?: boolean;
  highlightLines?: number[];
  title?: string;
}

/**
 * Component to display a Ruby code example with syntax highlighting
 * Just pass the name of the example and it will be loaded from the examples directory
 */
export function RubyCodeExample({
  name,
  showLineNumbers = false,
  highlightLines = [],
  title,
}: RubyCodeExampleProps) {
  // This will throw if the example doesn't exist
  const example = getCodeExample(name);

  return (
    <div className="my-6">
      {title && (
        <div className="font-medium text-sm mb-2 text-gray-700">{title}</div>
      )}
      <div className="overflow-hidden rounded-lg">
        <SyntaxHighlighter
          language="ruby"
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
            fontFamily:
              'ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace',
          }}
        >
          {example.code}
        </SyntaxHighlighter>
      </div>
    </div>
  );
}
