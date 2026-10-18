import {
  DEVELOPMENT_TOOLS,
  getGemDescription,
  getIntegrationRows,
  INTEGRATIONS,
} from '../gem-descriptions';
import { parseGemspec } from '../gemspec-parser';

describe('getGemDescription', () => {
  // The supported versions page fails to build for a gem without one
  it('describes every required dependency and every integration', () => {
    const dependencies = parseGemspec();

    expect(dependencies.length).toBeGreaterThan(0);
    for (const dependency of dependencies.filter((dep) => dep.type === 'required')) {
      expect(() => getGemDescription(dependency.name)).not.toThrow();
    }
    for (const integration of INTEGRATIONS) {
      expect(() => getGemDescription(integration.name)).not.toThrow();
    }
  });
});

describe('getIntegrationRows', () => {
  it('lists every development dependency that is an integration, with its gemspec requirement', () => {
    const dependencies = parseGemspec();
    const rows = getIntegrationRows(dependencies);
    const names = rows.map((row) => row.name);

    for (const dep of dependencies.filter((d) => d.type === 'development')) {
      if (DEVELOPMENT_TOOLS.includes(dep.name)) {
        expect(names).not.toContain(dep.name);
      } else {
        expect(rows.find((row) => row.name === dep.name)?.testedWithText).toBe(dep.version);
      }
    }
  });

  it('gives a tested version for the integrations that are not in the gemspec', () => {
    const rows = getIntegrationRows(parseGemspec());

    expect(rows.find((row) => row.name === 'puma')?.testedWithText).toBe('~> 7.0 (Rails test app)');
    expect(rows.find((row) => row.name === 'good_job')?.testedWithText).toMatch(/stand-ins/);
    expect(rows.find((row) => row.name === 'activejob')?.testedWithText).toMatch(/Rails test app/);
  });

  it('fails for a development dependency it does not know', () => {
    expect(() =>
      getIntegrationRows([{ name: 'new_gem', version: '~> 1.0', type: 'development' }]),
    ).toThrow(/new_gem is a development dependency/);
  });
});
