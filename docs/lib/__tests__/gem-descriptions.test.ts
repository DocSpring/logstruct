import { getGemDescription } from '../gem-descriptions';
import { parseGemspec } from '../gemspec-parser';

describe('getGemDescription', () => {
  // The supported versions page fails to build for a gem without one
  it('describes every gem in logstruct.gemspec', () => {
    const dependencies = parseGemspec();

    expect(dependencies.length).toBeGreaterThan(0);
    for (const dependency of dependencies) {
      expect(() => getGemDescription(dependency.name)).not.toThrow();
    }
  });
});
