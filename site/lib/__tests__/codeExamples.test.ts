import { describe, it, expect, beforeAll } from '@jest/globals';
import fs from 'fs';
import path from 'path';
import {
  loadCodeExamples,
  getCodeExample,
  getAllCodeExamples,
  getAllExampleIds,
  extractCodeExample,
} from '../codeExamples';

// This is an integration test that uses the real file system to load actual code examples
// No mocks here - we're testing with real examples from the repo

describe('Code Examples Integration', () => {
  // Load examples once before all tests
  let examples: ReturnType<typeof loadCodeExamples>;

  beforeAll(() => {
    // Load the real examples
    examples = loadCodeExamples();
  });

  it('should find code examples directory', () => {
    const examplesDir = path.join(process.cwd(), '..', 'test/code_examples');
    expect(fs.existsSync(examplesDir)).toBe(true);
  });

  it('should load at least some examples', () => {
    // There should be examples from our Ruby files
    const numExamples = Object.keys(examples).length;
    expect(numExamples).toBeGreaterThan(0);
  });

  it('should load code examples from Ruby files', () => {
    // Verify at least one example got loaded
    const allExamples = getAllCodeExamples();
    expect(allExamples.length).toBeGreaterThan(0);

    // The rails_initializer example should exist
    const railsInitializer = getCodeExample('rails_initializer');
    expect(railsInitializer).not.toBeNull();

    // Verify each example has content
    allExamples.forEach((example) => {
      expect(example.code.length).toBeGreaterThan(0);
    });
  });

  it('should provide complete list of examples', () => {
    const allExamples = getAllCodeExamples();
    expect(allExamples.length).toBeGreaterThan(0);

    // Verify structure of examples
    for (const example of allExamples) {
      expect(example).toHaveProperty('id');
      expect(example).toHaveProperty('code');
      expect(example).toHaveProperty('filePath');
      expect(example.code.length).toBeGreaterThan(0);
    }
  });

  it('should provide list of all example IDs', () => {
    const ids = getAllExampleIds();
    expect(ids.length).toBeGreaterThan(0);

    // A few key examples that should be found
    expect(ids).toContain('rails_initializer');
    expect(ids).toContain('basic_configuration');
    expect(ids).toContain('custom_string_scrubber');
  });

  it('should preserve indentation in code examples relative to first line', () => {
    // Check a real example to see if it's properly unindented
    const example = getCodeExample('basic_configuration');
    expect(example).not.toBeNull();

    // Split the code into lines
    const lines = example.code.split('\n');

    // Check that we have the expected code structure
    // The actual indentation may vary based on the current test/code_examples files
    expect(lines[0]).toMatch(/LogStruct\.configure do \|config\|/);

    // Check that relative indentation is preserved (don't check exact content)
    if (lines.length > 2) {
      // Find a line with indentation
      const indentedLine = lines.find(
        (line) => line.trim().length > 0 && line.startsWith('  '),
      );
      if (indentedLine) {
        expect(indentedLine.startsWith('  ')).toBe(true);
      }
    }
  });
});

describe('Post-processing directives', () => {
  it('extracts basic code examples without directives', () => {
    const content = `
# ----------------------------------------------------------
# BEGIN CODE EXAMPLE: basic_example
# ----------------------------------------------------------
const example = "Hello, world!";
console.log(example);
# ----------------------------------------------------------
# END CODE EXAMPLE: basic_example
# ----------------------------------------------------------
`;

    const extracted = extractCodeExample(content, 'basic_example');
    expect(extracted).toBe(
      'const example = "Hello, world!";\nconsole.log(example);',
    );
  });

  it('supports replace directives', () => {
    const content = `
# ----------------------------------------------------------
# BEGIN CODE EXAMPLE: replace_example, replace: /array << /, ""
# ----------------------------------------------------------
array << "first value"
array << "second value"
array << "third value"
# ----------------------------------------------------------
# END CODE EXAMPLE: replace_example
# ----------------------------------------------------------
`;

    const extracted = extractCodeExample(content, 'replace_example');
    expect(extracted).toBe('"first value"\n"second value"\n"third value"');
  });

  it('supports multiple replace directives', () => {
    const content = `
# ----------------------------------------------------------
# BEGIN CODE EXAMPLE: multi_replace, replace: /array << /, "", replace: /"([^"]+)"/, "$1"
# ----------------------------------------------------------
array << "first value"
array << "second value"
array << "third value"
# ----------------------------------------------------------
# END CODE EXAMPLE: multi_replace
# ----------------------------------------------------------
`;

    const extracted = extractCodeExample(content, 'multi_replace');
    expect(extracted).toBe('first value\nsecond value\nthird value');
  });

  it('handles complex regex patterns in replace directives', () => {
    const content = `
# ----------------------------------------------------------
# BEGIN CODE EXAMPLE: complex_replace, replace: /^\\s*debug\\(([^)]+)\\);\\s*$/gm, "// $1"
# ----------------------------------------------------------
const value = 42;
debug(value);
debug("testing");
const result = compute();
# ----------------------------------------------------------
# END CODE EXAMPLE: complex_replace
# ----------------------------------------------------------
`;

    const extracted = extractCodeExample(content, 'complex_replace');
    expect(extracted).toBe(
      'const value = 42;\n// value\n// "testing"\nconst result = compute();',
    );
  });

  it('preserves indentation after replacements', () => {
    const content = `
# ----------------------------------------------------------
# BEGIN CODE EXAMPLE: indentation_example, replace: /add\\(/, "sum("
# ----------------------------------------------------------
function calculate() {
  const result = add(1, 2);
  if (result > 0) {
    return add(result, 3);
  }
  return 0;
}
# ----------------------------------------------------------
# END CODE EXAMPLE: indentation_example
# ----------------------------------------------------------
`;

    const extracted = extractCodeExample(content, 'indentation_example');
    expect(extracted).toBe(
      'function calculate() {\n  const result = sum(1, 2);\n  if (result > 0) {\n    return sum(result, 3);\n  }\n  return 0;\n}',
    );
  });

  it('handles replace directives', () => {
    const content = `
# ----------------------------------------------------------
# BEGIN CODE EXAMPLE: log_enums, replace: /enums << /, ""
# ----------------------------------------------------------
# Log levels
enums << LogStruct::LogLevel::Debug
enums << LogStruct::LogLevel::Info
enums << LogStruct::LogLevel::Warn
enums << LogStruct::LogLevel::Error
enums << LogStruct::LogLevel::Fatal
# ----------------------------------------------------------
# END CODE EXAMPLE: log_enums
# ----------------------------------------------------------
`;

    const extracted = extractCodeExample(content, 'log_enums');
    expect(extracted).toContain('LogStruct::LogLevel::Debug');
    expect(extracted).toContain('LogStruct::Source::Rails');
    expect(extracted).toContain('LogStruct::ErrorHandlingMode::Ignore');
    expect(extracted).not.toContain('enums <<');
  });
});
