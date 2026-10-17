import enums from '@/generated/logstruct/sorbet-enums.json';
import {
  ENUM_DESCRIPTIONS,
  ENUM_VALUE_DESCRIPTIONS,
  getEnumValueDescription,
} from '../enum-descriptions';

const ENUMS = enums as Record<string, { values: Array<{ name: string }> }>;

describe('Enum descriptions', () => {
  test.each(Object.keys(ENUM_DESCRIPTIONS))('describes every value of %s', (enumName) => {
    for (const { name } of ENUMS[enumName].values) {
      expect(ENUM_VALUE_DESCRIPTIONS[enumName][name]).toBeTruthy();
    }
  });

  test('describes the error handling modes as LogStruct handles errors', () => {
    const mode = (name: string) => getEnumValueDescription('LogStruct::ErrorHandlingMode', name);
    expect(mode('Raise')).toBe('Raise the error, without logging or reporting it');
    expect(mode('LogProduction')).toContain('local_environments (development and test by default)');
    expect(mode('ReportProduction')).toContain(
      'local_environments (development and test by default)',
    );
    expect(mode('LogProduction')).not.toMatch(/\bdev\b|development\b(?! and test)/);
  });

  test("describes Puma's source as its lifecycle events and request errors", () => {
    expect(getEnumValueDescription('LogStruct::Source', 'Puma')).toBe(
      'Puma server lifecycle events and request errors',
    );
  });

  test('describes Shrine and CarrierWave as more than uploads', () => {
    expect(getEnumValueDescription('LogStruct::Source', 'Shrine')).toContain('deletes');
    expect(getEnumValueDescription('LogStruct::Source', 'CarrierWave')).toContain('deletes');
  });

  test('says a delivery line is logged before the mail is sent', () => {
    expect(getEnumValueDescription('LogStruct::Event', 'Delivery')).toContain('before_deliver');
  });
});
