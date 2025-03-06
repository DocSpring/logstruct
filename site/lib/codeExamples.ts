import fs from 'fs';
import path from 'path';

interface CodeExample {
  id: string;
  code: string;
  filePath: string;
}

// Map of example ID to code content
const CODE_EXAMPLES: Record<string, CodeExample> = generateCodeExamples();

/**
 * Extracts a code example from file content using the BEGIN/END markers with separators
 */
function extractCodeExample(content: string, id: string): string | null {
  const startPattern = new RegExp(
    `# -+\\s*\n# BEGIN CODE EXAMPLE: ${id}\\s*\n# -+`,
  );
  const endPattern = new RegExp(
    `# -+\\s*\n# END CODE EXAMPLE: ${id}\\s*\n# -+`,
  );

  const startMatch = content.match(startPattern);
  if (!startMatch) return null;

  const startIndex = startMatch.index! + startMatch[0].length;
  const contentAfterStart = content.slice(startIndex);

  const endMatch = contentAfterStart.match(endPattern);
  if (!endMatch) return null;

  // Extract the code between markers and trim any leading/trailing whitespace
  return contentAfterStart.slice(0, endMatch.index).trim();
}

/**
 * Generates all code examples at build time
 */
function generateCodeExamples(): Record<string, CodeExample> {
  const examples: Record<string, CodeExample> = {};

  // Path to examples directory (relative to project root)
  const examplesDir = path.join(process.cwd(), '..', 'examples');

  // Check if directory exists
  if (!fs.existsSync(examplesDir)) {
    throw new Error(`Examples directory not found: ${examplesDir}`);
  }

  // Get all Ruby files in the directory
  const files = fs
    .readdirSync(examplesDir)
    .filter((file) => file.endsWith('.rb'));

  for (const file of files) {
    const filePath = path.join(examplesDir, file);
    const content = fs.readFileSync(filePath, 'utf8');

    // Extract all example IDs from this file
    const regex = /# BEGIN CODE EXAMPLE: (\w+)/g;
    let match;

    while ((match = regex.exec(content)) !== null) {
      const id = match[1];
      const code = extractCodeExample(content, id);

      if (code) {
        examples[id] = {
          id,
          code,
          filePath: path.relative(process.cwd(), filePath),
        };
      }
    }
  }

  return examples;
}

/**
 * Gets a code example by ID
 * This can be used in components via static generation or server components
 */
export function getCodeExample(id: string): CodeExample | null {
  return CODE_EXAMPLES[id] || null;
}

/**
 * Gets all available code examples
 */
export function getAllCodeExamples(): CodeExample[] {
  return Object.values(CODE_EXAMPLES);
}

/**
 * Gets all code example IDs
 */
export function getAllExampleIds(): string[] {
  return Object.keys(CODE_EXAMPLES);
}
