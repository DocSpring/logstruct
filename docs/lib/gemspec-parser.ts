// Reads logstruct.gemspec, the Gemfile and the CI workflow, for the supported versions page.
// Each function throws when it can't find what it looks for, so a change to those files that
// the page doesn't understand fails the build instead of publishing wrong versions.
import fs from 'node:fs';
import path from 'node:path';

export interface GemDependency {
  name: string;
  version: string;
  // Runtime dependencies are required; development dependencies are the gems LogStruct's own
  // tests install (mostly the optional integrations)
  type: 'required' | 'development';
}

export interface CiCombination {
  ruby: string;
  // A release, or "main" for Rails' main branch
  rails: string;
}

function readRepoFile(relativePath: string): string {
  // The docs build runs in docs/, so the repository root is one level up
  return fs.readFileSync(path.join(process.cwd(), '..', relativePath), 'utf8');
}

function readGemspec(): string {
  return readRepoFile('logstruct.gemspec');
}

// The quoted strings in a dependency's requirement list: `"~> 7.2"` or `">= 4.1", "< 6.0"`
function parseRequirements(list: string): string {
  const requirements = Array.from(list.matchAll(/["']([^"']+)["']/g), (match) => match[1]);
  return requirements.length > 0 ? requirements.join(', ') : 'any';
}

export function parseGemspec(): GemDependency[] {
  const gemspecContent = readGemspec();
  const dependencyPattern =
    /spec\.add_(development_)?dependency\s+["']([^"']+)["']((?:\s*,\s*["'][^"']+["'])*)/g;

  const dependencies: GemDependency[] = Array.from(
    gemspecContent.matchAll(dependencyPattern),
    (match) => ({
      name: match[2],
      version: parseRequirements(match[3]),
      type: match[1] ? 'development' : 'required',
    }),
  );

  if (dependencies.length === 0) {
    throw new Error('No dependencies could be parsed from logstruct.gemspec');
  }

  // Required dependencies first, then alphabetical
  return dependencies.sort((a, b) => {
    if (a.type !== b.type) {
      return a.type === 'required' ? -1 : 1;
    }
    return a.name.localeCompare(b.name);
  });
}

// ">= 3.3.0" -> "3.3.0". Only a lower bound can be written as "X or newer".
function lowerBound(requirement: string, what: string): string {
  const match = requirement.match(/^>=\s*(\d+(?:\.\d+)*)$/);
  if (!match) {
    throw new Error(`Expected ${what} to be ">= <version>", got "${requirement}"`);
  }
  return match[1];
}

// The lowest Ruby version, from `spec.required_ruby_version`
export function parseMinimumRubyVersion(): string {
  const match = readGemspec().match(/spec\.required_ruby_version\s*=\s*["']([^"']+)["']/);
  if (!match) {
    throw new Error('No required_ruby_version in logstruct.gemspec');
  }
  return lowerBound(match[1], 'required_ruby_version');
}

// The Rails gems LogStruct depends on, which must all have the same lower bound
export const RAILS_DEPENDENCIES = ['railties', 'actionpack', 'activesupport'];

export function parseMinimumRailsVersion(): string {
  const dependencies = parseGemspec();
  const versions = RAILS_DEPENDENCIES.map((name) => {
    const dependency = dependencies.find((dep) => dep.name === name && dep.type === 'required');
    if (!dependency) {
      throw new Error(`logstruct.gemspec doesn't depend on ${name}`);
    }
    return lowerBound(dependency.version, `the ${name} requirement`);
  });
  if (new Set(versions).size !== 1) {
    throw new Error(`Expected ${RAILS_DEPENDENCIES.join(', ')} to require the same version`);
  }
  return versions[0];
}

// The Rails version in LogStruct's Gemfile, which the unit tests run with in every CI job
export function parseUnitTestRailsVersion(): string {
  const match = readRepoFile('Gemfile').match(/^gem\s+"rails",\s*"~>\s*(\d+\.\d+)/m);
  if (!match) {
    throw new Error('No `gem "rails", "~> X.Y"` line in the Gemfile');
  }
  return match[1];
}

// The Puma version the generated Rails test app installs (rails_test_app/create_app.rb pins
// "~> 6.4" only for Rails 7.0, which LogStruct no longer supports)
export function parseRailsTestAppPumaRequirement(): string {
  const createApp = readRepoFile('rails_test_app/create_app.rb');
  const match = createApp.match(/puma_requirement = if[^\n]*\n[^\n]*\n\s*else\s*\n\s*"([^"]+)"/);
  if (!match) {
    throw new Error('No puma_requirement in rails_test_app/create_app.rb');
  }
  return match[1];
}

// The Ruby and Rails versions CI tests in .github/workflows/test.yml: each entry of the test
// matrix, then the pilot job (RAILS_VERSION "latest" is Rails' main branch, see
// rails_test_app/create_app.rb)
export function parseCiCombinations(): CiCombination[] {
  const workflow = readRepoFile('.github/workflows/test.yml');

  const combinations: CiCombination[] = Array.from(
    workflow.matchAll(/-\s+name:\s*'[^']*'\s*\n\s*ruby:\s*'([^']+)'\s*\n\s*rails:\s*'([^']+)'/g),
    (match) => ({ ruby: match[1], rails: match[2] }),
  );
  if (combinations.length === 0) {
    throw new Error('No ruby/rails entries found in the test matrix of .github/workflows/test.yml');
  }

  const pilot = workflow.match(
    /^ {2}pilot:\n[\s\S]*?^ {4}env:\n\s*RAILS_VERSION:\s*'([^']+)'\n\s*RUBY_VERSION:\s*'([^']+)'/m,
  );
  if (!pilot) {
    throw new Error(
      'No RAILS_VERSION and RUBY_VERSION in the pilot job of .github/workflows/test.yml',
    );
  }
  const pilotRails = ['latest', 'main'].includes(pilot[1]) ? 'main' : pilot[1];
  combinations.push({ ruby: pilot[2], rails: pilotRails });

  return combinations;
}
