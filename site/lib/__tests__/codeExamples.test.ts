import { describe, it, expect, beforeAll } from '@jest/globals';
import fs from 'fs';
import path from 'path';
import {
  loadCodeExamples,
  getCodeExample,
  getAllCodeExamples,
  getAllExampleIds,
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
    console.log(`Found ${numExamples} examples from real files`);
  });

  it('should load code examples from Ruby files', () => {
    // Verify at least one example got loaded
    const allExamples = getAllCodeExamples();
    expect(allExamples.length).toBeGreaterThan(0);

    // The rails_initializer example should exist
    const railsInitializer = getCodeExample('rails_initializer');
    expect(railsInitializer).not.toBeNull();

    // List all examples with their file paths for diagnostic purposes
    console.log("All found examples:")
    allExamples.forEach((example) => {
      expect(example.code.length).toBeGreaterThan(0);
      console.log(`- ${example.id} (from ${example.filePath})`);
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
});
