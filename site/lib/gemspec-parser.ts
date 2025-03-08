// This module directly parses the gemspec file to extract dependencies
import fs from 'fs';
import path from 'path';

export interface GemDependency {
  name: string;
  version: string;
  type: 'required' | 'optional';
}

// Fallback dependencies in case of parsing errors
const fallbackDependencies: GemDependency[] = [
  { name: 'rails', version: '>= 7.0', type: 'required' },
  { name: 'lograge', version: '>= 0.11', type: 'required' },
  { name: 'sorbet-runtime', version: '>= 0.5', type: 'required' },
  { name: 'bugsnag', version: '~> 6.26', type: 'optional' },
  { name: 'carrierwave', version: '~> 3.0', type: 'optional' },
  { name: 'honeybadger', version: '~> 5.4', type: 'optional' },
  { name: 'rollbar', version: '~> 3.4', type: 'optional' },
  { name: 'sentry-ruby', version: '~> 5.15', type: 'optional' },
  { name: 'shrine', version: '~> 3.5', type: 'optional' },
  { name: 'sidekiq', version: '~> 7.2', type: 'optional' },
  { name: 'sorbet', version: '~> 0.5', type: 'optional' },
];

export function parseGemspec(): GemDependency[] {
  try {
    // Path to the gemspec file (relative to site directory)
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
      console.warn('No dependencies found in gemspec, using fallback data');
      return fallbackDependencies;
    }

    // Sort dependencies alphabetically, but put required dependencies first
    return dependencies.sort((a, b) => {
      if (a.type !== b.type) {
        return a.type === 'required' ? -1 : 1;
      }
      return a.name.localeCompare(b.name);
    });
  } catch (error) {
    console.error('Error parsing gemspec:', error);
    // Return the fallback data in case of error
    return fallbackDependencies;
  }
}
