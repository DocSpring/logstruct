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

  it('should find examples directory', () => {
    const examplesDir = path.join(process.cwd(), '..', 'examples');
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
    
    // This should be true: comment line at first level, code line at first level
    // The actual indentation after unindenting should preserve the relative structure
    expect(lines[0]).toBe('# Configure LogStruct with a block');
    expect(lines[1]).toBe('LogStruct.configure do |config|');
  });
});
