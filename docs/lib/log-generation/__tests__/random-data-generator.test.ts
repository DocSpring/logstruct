import { Event, Level, Source } from '@/generated/logstruct';
import { RandomDataGenerator } from '../random-data-generator';
import { SampleData } from '../sample-data';
import { scrubString } from '../string-scrubber';

describe('RandomDataGenerator', () => {
  let generator: RandomDataGenerator;

  beforeEach(() => {
    // Use a fixed seed for deterministic tests
    generator = new RandomDataGenerator(12345);
  });

  test('should generate consistent random values with the same seed', () => {
    const generator1 = new RandomDataGenerator(42);
    const generator2 = new RandomDataGenerator(42);

    expect(generator1.randomInt(1, 100)).toBe(generator2.randomInt(1, 100));
    expect(generator1.randomFloat(1, 100)).toBe(generator2.randomFloat(1, 100));
    expect(generator1.randomHex(8)).toBe(generator2.randomHex(8));
  });

  test('should generate random enum values', () => {
    expect(Object.values(Level)).toContain(generator.randomEnum(Level));
    expect(Object.values(Source)).toContain(generator.randomEnum(Source));
    expect(Object.values(Event)).toContain(generator.randomEnum(Event));
  });

  test('should generate random email addresses', () => {
    const email = generator.randomEmail();
    const [namePart, domain] = email.split('@');
    const [firstName, lastName] = namePart.split('.');

    expect(SampleData.FIRST_NAMES.map((name) => name.toLowerCase())).toContain(firstName);
    expect(SampleData.LAST_NAMES.map((name) => name.toLowerCase())).toContain(lastName);
    expect(SampleData.DOMAINS).toContain(domain);
  });

  test('generates UUIDs', () => {
    expect(generator.randomUuid()).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
    );
  });

  test("generates card and phone numbers that LogStruct's scrubbers find", () => {
    for (let i = 0; i < 10; i++) {
      expect(scrubString(generator.randomCreditCard())).toBe('[CREDIT_CARD]');
      expect(scrubString(generator.randomPhone())).toBe('[PHONE]');
    }
  });

  test('generates raw values, for the filters to filter', () => {
    expect(generator.randomPassword()).toMatch(/^[a-z-]+\d{3}!$/);
    expect(SampleData.IP_ADDRESSES).toContain(generator.randomIP());
  });
});
