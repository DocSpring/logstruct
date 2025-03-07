// Server-side only imports
import fs from 'node:fs';
import path from 'node:path';

export interface CodeExample {
  id: string;
  code: string;
  filePath: string;
}

// Global cache for code examples
let CODE_EXAMPLES: Record<string, CodeExample> = {};

// Track last load time for development mode
let lastLoadTime = 0;
const RELOAD_INTERVAL_MS = 1000; // 1 second

/**
 * Unindents a code block by detecting and removing consistent whitespace
 * from the beginning of each line
 */
function unindentCode(code: string): string {
  // Split into lines for processing
  const lines = code.split('\n');

  // Find non-empty lines to determine minimum indentation
  const nonEmptyLines = lines.filter((line) => line.trim().length > 0);
  if (!nonEmptyLines.length) return code;

  // Calculate the minimum indentation across all non-empty lines
  const indentSizes = nonEmptyLines.map((line) => {
    const match = line.match(/^(\s*)/);
    return match ? match[1].length : 0;
  });

  const minIndent = Math.min(...indentSizes);

  // If no common indentation found, return the original code
  if (minIndent === 0) return code;

  // Remove the common indentation from each line, but only if the line
  // has enough characters to avoid cutting into content
  return lines
    .map((line) => {
      // Only remove indentation from non-empty lines
      if (line.trim().length === 0) return line;
      // Only remove up to the amount of leading whitespace
      const leadingSpaceMatch = line.match(/^(\s*)/);
      const leadingSpace = leadingSpaceMatch ? leadingSpaceMatch[0].length : 0;
      const toRemove = Math.min(minIndent, leadingSpace);
      return line.substring(toRemove);
    })
    .join('\n');
}

/**
 * Interface for post-processing directives
 */
interface PostProcessingDirective {
  type: 'replace';
  pattern: RegExp;
  replacement: string;
}

/**
 * Extracts a code example from file content using the BEGIN/END markers with separators
 * and applies any post-processing directives
 */
export function extractCodeExample(content: string, id: string): string | null {
  // Enhanced pattern to capture post-processing directives
  const startPattern = new RegExp(
    `\\s*#\\s*-+\\s*(?:\n|\\r\\n)\\s*#\\s*BEGIN CODE EXAMPLE:\\s*${id}(?:,\\s*([^\\n\\r]*))?\\s*(?:\n|\\r\\n)\\s*#\\s*-+`,
  );
  const endPattern = new RegExp(
    `\\s*#\\s*-+\\s*(?:\n|\\r\\n)\\s*#\\s*END CODE EXAMPLE:\\s*${id}\\s*(?:\n|\\r\\n)\\s*#\\s*-+`,
  );

  const startMatch = content.match(startPattern);
  if (!startMatch) return null;

  // Extract directives if present
  const directives: PostProcessingDirective[] = [];
  if (startMatch[1]) {
    const directivesStr = startMatch[1].trim();
    
    // Parse replace directives
    if (directivesStr.includes('replace:')) {
      // Better regex to handle both quoted and non-quoted replacements
      // First, let's simplify by splitting on 'replace:' to get all directives
      const parts = directivesStr.split('replace:');
      
      for (let i = 1; i < parts.length; i++) {
        try {
          const part = parts[i].trim();
          
          // Find the pattern part (between / and /)
          const patternMatch = part.match(/^\s*\/([^/]+)\/([gimsuy]*)/);
          if (!patternMatch) continue;
          
          const pattern = patternMatch[1];
          const flags = patternMatch[2] || '';
          
          // Find the replacement part (after the last comma or the whole remainder)
          let replacementPart = part.substring(patternMatch[0].length).trim();
          
          // If it starts with a comma, remove it
          if (replacementPart.startsWith(',')) {
            replacementPart = replacementPart.substring(1).trim();
          }
          
          // Handle quoted replacement
          let replacement = '';
          if (replacementPart.startsWith('"') && replacementPart.includes('"')) {
            // Extract text between first and second double quotes
            const quoteMatch = replacementPart.match(/"([^"]*)"/);
            if (quoteMatch) {
              replacement = quoteMatch[1];
            }
          } else {
            // If no quotes, just take the entire string up to the next directive or comma
            const endIndex = replacementPart.indexOf(',');
            replacement = endIndex > -1 
              ? replacementPart.substring(0, endIndex).trim() 
              : replacementPart.trim();
          }
          
          // Create the directive
          directives.push({
            type: 'replace',
            pattern: new RegExp(pattern, flags),
            replacement: replacement
          });
        } catch (error) {
          console.warn(`Invalid replace directive in: ${part}`, error);
        }
      }
    }
  }

  const startIndex = startMatch.index! + startMatch[0].length;
  const contentAfterStart = content.slice(startIndex);

  const endMatch = contentAfterStart.match(endPattern);
  if (!endMatch) return null;

  // Extract the code between markers without trimming (leading spaces are important)
  let extractedCode = contentAfterStart.slice(0, endMatch.index);

  // Apply post-processing directives
  if (directives.length > 0) {
    for (const directive of directives) {
      if (directive.type === 'replace') {
        // Apply the replacement globally if not already specified in the pattern flags
        if (!directive.pattern.flags.includes('g')) {
          const regex = new RegExp(directive.pattern.source, directive.pattern.flags + 'g');
          extractedCode = extractedCode.replace(regex, directive.replacement);
        } else {
          extractedCode = extractedCode.replace(directive.pattern, directive.replacement);
        }
      }
    }
  }

  // Remove empty lines at the beginning and end
  const trimmedCode = extractedCode.replace(/^\s*\n/, '').replace(/\s*$/, '');

  // Unindent the code by removing consistent whitespace from the left
  return unindentCode(trimmedCode);
}

/**
 * Loads all code examples from the examples directory
 * In development, this reloads on demand to pick up changes
 * In production, this loads once and caches the result
 */
export function loadCodeExamples(): Record<string, CodeExample> {
  const examples: Record<string, CodeExample> = {};

  try {
    // Path to code examples directory (relative to project root)
    const examplesDir = path.join(process.cwd(), '..', 'test/code_examples');

    // Check if directory exists
    if (!fs.existsSync(examplesDir)) {
      console.warn(`Examples directory not found: ${examplesDir}`);
      return examples;
    }

    // Get all Ruby files in the directory
    const files = fs
      .readdirSync(examplesDir)
      .filter((file) => file.endsWith('.rb'));

    for (const file of files) {
      const filePath = path.join(examplesDir, file);
      const content = fs.readFileSync(filePath, 'utf8');

      const regex = /\s*#\s*BEGIN CODE EXAMPLE:\s*(\w+)(?:,\s*[^)\n\r]*)?/g;
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
  } catch (error) {
    console.error('Error loading code examples:', error);
  }

  // Update the global cache and load time
  CODE_EXAMPLES = examples;
  lastLoadTime = Date.now();

  return examples;
}

/**
 * Ensures examples are loaded and up-to-date
 * In development, reloads if enough time has passed
 * In production, loads once at startup
 */
function ensureExamplesLoaded(): void {
  const isDevelopment = process.env.NODE_ENV === 'development';

  // In development, reload periodically
  if (isDevelopment && Date.now() - lastLoadTime > RELOAD_INTERVAL_MS) {
    loadCodeExamples();
  }
  // In production or if not loaded yet, load once
  else if (Object.keys(CODE_EXAMPLES).length === 0) {
    loadCodeExamples();
  }
}

/**
 * Gets a code example by ID
 * This can be used in components via static generation or server components
 * @throws Error if the example with the given ID doesn't exist
 */
export function getCodeExample(id: string): CodeExample {
  ensureExamplesLoaded();
  const example = CODE_EXAMPLES[id];
  if (!example) {
    throw new Error(
      `Code example not found: "${id}". Make sure this example exists in the examples directory.`,
    );
  }
  return example;
}

/**
 * Gets all available code examples
 */
export function getAllCodeExamples(): CodeExample[] {
  ensureExamplesLoaded();
  return Object.values(CODE_EXAMPLES);
}

/**
 * Gets all code example IDs
 */
export function getAllExampleIds(): string[] {
  ensureExamplesLoaded();
  return Object.keys(CODE_EXAMPLES);
}

// Initialize examples in production at module load time
if (process.env.NODE_ENV === 'production') {
  loadCodeExamples();
}
