import { RandomDataGenerator } from '../random-data-generator';
import { SampleData } from '../sample-data';
import { Level, Source, Event } from '../log-types';

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
    const level = generator.randomEnum(Level);
    expect(Object.values(Level)).toContain(level);

    const source = generator.randomEnum(Source);
    expect(Object.values(Source)).toContain(source);

    const event = generator.randomEnum(Event);
    expect(Object.values(Event)).toContain(event);
  });

  test('should generate random email addresses', () => {
    const email = generator.randomEmail();

    expect(email).toContain('@');
    expect(email.split('@').length).toBe(2);

    // Should include a name from our sample data
    const firstNames = SampleData.FIRST_NAMES.map((name) => name.toLowerCase());
    const lastNames = SampleData.LAST_NAMES.map((name) => name.toLowerCase());

    const namePart = email.split('@')[0];
    const domain = email.split('@')[1];

    // Check first part is firstName.lastName format
    const nameParts = namePart.split('.');
    expect(nameParts.length).toBe(2);
    expect(firstNames).toContain(nameParts[0]);
    expect(lastNames).toContain(nameParts[1]);

    // Check domain is from our list
    expect(SampleData.DOMAINS).toContain(domain);
  });

  test('should generate filtered email addresses', () => {
    const filteredEmail = generator.randomFilteredEmailString();

    expect(filteredEmail).toMatch(/^\[EMAIL:[a-f0-9]{6}\]$/);
  });

  test('should generate filtered email address objects', () => {
    const filteredEmailObj = generator.randomFilteredEmailObject();

    expect(filteredEmailObj).toHaveProperty('_filtered');
    expect(filteredEmailObj._filtered).toHaveProperty('_class', 'String');
    expect(filteredEmailObj._filtered).toHaveProperty('_bytes');
    expect(filteredEmailObj._filtered).toHaveProperty('_hash');
    expect(filteredEmailObj._filtered._hash).toMatch(/^[a-f0-9]{6}$/);
  });

  test('should generate filtered hash objects', () => {
    const filteredHash = generator.filteredHash('password');

    expect(filteredHash).toHaveProperty('_filtered');
    expect(filteredHash._filtered).toHaveProperty('_class', 'Hash');
    expect(filteredHash._filtered).toHaveProperty('_keys_count');
    expect(filteredHash._filtered).toHaveProperty('_keys');
    expect(filteredHash._filtered).toHaveProperty('_bytes');

    // Check that keys include password-related fields
    expect(filteredHash._filtered._keys).toContain('password');
  });

  test('should generate filtered array objects', () => {
    const filteredArray = generator.filteredArray(5);

    expect(filteredArray).toHaveProperty('_filtered');
    expect(filteredArray._filtered).toHaveProperty('_class', 'Array');
    expect(filteredArray._filtered).toHaveProperty('_length', 5);
    expect(filteredArray._filtered).toHaveProperty('_bytes');
  });

  test('should generate filtered sensitive values', () => {
    expect(generator.randomPassword()).toBe('[PASSWORD]');
    expect(generator.randomCreditCard()).toBe('[CREDIT_CARD]');
    expect(generator.randomPhone()).toBe('[PHONE]');
    expect(generator.randomIP(true)).toBe('[IP]');
  });

  test('should generate unfiltered sensitive values when requested', () => {
    expect(generator.randomPassword(false)).toContain('password');
    expect(generator.randomCreditCard(false)).toMatch(
      /^\d{4}-\d{4}-\d{4}-\d{4}$/,
    );
    expect(generator.randomPhone(false)).toMatch(/^\+1-\d{3}-\d{3}-\d{4}$/);
    expect(SampleData.IP_ADDRESSES).toContain(generator.randomIP(false));
  });
});
