// This module directly parses the gemspec file to extract dependencies
import fs from 'fs';
import path from 'path';

export interface GemDependency {
  name: string;
  version: string;
  type: 'required' | 'optional';
}

export function parseGemspec(): GemDependency[] {
  try {
    // Path to the gemspec file (relative to docs directory)
    const gemspecPath = path.join(process.cwd(), '..', 'logstruct.gemspec');

    // Read the gemspec file
    const gemspecContent = fs.readFileSync(gemspecPath, 'utf8');

    // Define regex patterns to match dependencies
    const requiredDepPattern =
      /spec\.add_dependency\s+["']([^"']+)["'],\s*["']([^"']+)["']/g;
    const optionalDepPattern =
      /spec\.add_development_dependency\s+["']([^"']+)["'],\s*["']([^"']+)["']/g;

    const dependencies: GemDependency[] = [];

    // Extract required dependencies
    let match;
    while ((match = requiredDepPattern.exec(gemspecContent)) !== null) {
      dependencies.push({
        name: match[1],
        version: match[2],
        type: 'required',
      });
    }

    // Extract optional dependencies
    while ((match = optionalDepPattern.exec(gemspecContent)) !== null) {
      dependencies.push({
        name: match[1],
        version: match[2],
        type: 'optional',
      });
    }

    // If no dependencies were found, use fallback data
    if (dependencies.length === 0) {
      throw new Error('No dependencies could be parsed from gemspec!');
    }

    // Sort dependencies alphabetically, but put required dependencies first
    return dependencies.sort((a, b) => {
      if (a.type !== b.type) {
        return a.type === 'required' ? -1 : 1;
      }
      return a.name.localeCompare(b.name);
    });
  } catch (error) {
    throw new Error('Error parsing gemspec! ' + error);
  }
}
