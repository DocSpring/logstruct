import fs from 'node:fs';
import path from 'node:path';
import {
  parseCiCombinations,
  parseGemspec,
  parseMinimumRailsVersion,
  parseMinimumRubyVersion,
  parseUnitTestRailsVersion,
} from '../gemspec-parser';

const gemspec = fs.readFileSync(path.join(process.cwd(), '..', 'logstruct.gemspec'), 'utf8');
const workflow = fs.readFileSync(
  path.join(process.cwd(), '..', '.github/workflows/test.yml'),
  'utf8',
);

describe('parseGemspec', () => {
  it('finds every dependency in logstruct.gemspec', () => {
    const declared = gemspec.match(/spec\.add_(development_)?dependency\s/g) ?? [];

    expect(parseGemspec()).toHaveLength(declared.length);
  });

  it('keeps every part of a requirement', () => {
    const ahoy = parseGemspec().find((dep) => dep.name === 'ahoy_matey');

    expect(ahoy).toEqual({ name: 'ahoy_matey', version: '>= 4.1, < 6.0', type: 'development' });
  });

  it('separates runtime dependencies from development dependencies', () => {
    const railties = parseGemspec().find((dep) => dep.name === 'railties');
    const sidekiq = parseGemspec().find((dep) => dep.name === 'sidekiq');

    expect(railties?.type).toBe('required');
    expect(sidekiq?.type).toBe('development');
  });
});

describe('versions', () => {
  it('reads the lowest Ruby version from required_ruby_version', () => {
    expect(gemspec).toContain(`spec.required_ruby_version = ">= ${parseMinimumRubyVersion()}"`);
  });

  it('reads the lowest Rails version from the Rails dependencies', () => {
    expect(gemspec).toContain(`spec.add_dependency "railties", ">= ${parseMinimumRailsVersion()}"`);
  });

  it('reads the Rails version the unit tests use from the Gemfile', () => {
    expect(parseUnitTestRailsVersion()).toMatch(/^\d+\.\d+$/);
  });
});

describe('parseCiCombinations', () => {
  it('lists each matrix entry and the pilot job', () => {
    const combinations = parseCiCombinations();
    const matrixEntries = workflow.match(/^\s+- name: 'Ruby /gm) ?? [];

    expect(combinations).toHaveLength(matrixEntries.length + 1);
    for (const combination of combinations) {
      expect(combination.ruby).toMatch(/^\d+\.\d+(\.\d+)?$/);
      expect(combination.rails).toMatch(/^(\d+\.\d+\.\d+|main)$/);
    }
    // The pilot job tests Rails' main branch (RAILS_VERSION "latest")
    expect(combinations[combinations.length - 1].rails).toBe('main');
  });

  // The page says "Ruby X or newer" and "Rails Y or newer": CI should test X and Y
  it('includes the lowest supported Ruby and Rails versions', () => {
    const combinations = parseCiCombinations();
    const lowestRuby = parseMinimumRubyVersion().split('.').slice(0, 2).join('.');
    const lowestRails = parseMinimumRailsVersion();

    expect(combinations.some((c) => c.ruby.startsWith(lowestRuby))).toBe(true);
    expect(combinations.some((c) => c.rails.startsWith(`${lowestRails}.`))).toBe(true);
  });
});
