// Server Component - used at build time for static generation
import React from 'react';
import { getCodeExample } from '@/lib/codeExamples';
import { CodeBlock } from './code-block';

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

  return (
    <CodeBlock
      language="ruby"
      showLineNumbers={showLineNumbers}
      highlightLines={highlightLines}
      title={title}
    >
      {getCodeExample(name)}
    </CodeBlock>
  );
}
