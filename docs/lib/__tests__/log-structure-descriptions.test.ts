// Jest globals are available in test environment without explicit import
import {
  getLogStructureDescription,
  LOG_STRUCTURE_DESCRIPTIONS,
} from '../log-structure-descriptions';

describe('Log Structure Descriptions', () => {
  it('has descriptions for all common log structures', () => {
    // Test that we have descriptions for the core log structures
    const expectedStructures = [
      'Plain',
      'Request',
      'Error',
      'ActiveJob',
      'ActionMailer',
      'ActiveStorage',
      'Shrine',
      'CarrierWave',
      'Sidekiq',
      'Security',
    ];

    // Check that all expected structures have descriptions
    expectedStructures.forEach((struct) => {
      expect(LOG_STRUCTURE_DESCRIPTIONS).toHaveProperty(struct);
      expect(LOG_STRUCTURE_DESCRIPTIONS[struct]).toBeTruthy();
    });
  });

  it('getLogStructureDescription returns the correct description', () => {
    // Test with a known structure
    expect(getLogStructureDescription('Plain')).toBe('For general purpose logging');
    expect(getLogStructureDescription('Request')).toBe('For HTTP request details');
  });

  it('getLogStructureDescription throws an error for unknown structures', () => {
    // Test with an unknown structure
    expect(() => getLogStructureDescription('NonExistentStructure')).toThrow(
      'No description found for log structure: NonExistentStructure. ' +
        'Add it to lib/log-structure-descriptions.ts',
    );
  });
});
