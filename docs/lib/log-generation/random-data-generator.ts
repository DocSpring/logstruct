import { isoAt, SampleData } from './sample-data';

/**
 * Utility for generating random data with seed support
 */
export class RandomDataGenerator {
  private seed: number;
  protected random: () => number;
  // The time the lines are written at (milliseconds since the epoch), or the clock's time if unset. A page
  // rendered on the server passes the same time to the browser, so both render the same lines.
  private fixedNow: number | undefined;

  constructor(seed?: number, now?: number) {
    this.seed = seed || Math.floor(Math.random() * 1000000);
    this.random = this.createRandomGenerator(this.seed);
    this.fixedNow = now;
  }

  /** The time now, in milliseconds since the epoch */
  nowMs(): number {
    return this.fixedNow ?? Date.now();
  }

  /** The time now, as LogStruct writes ts on a server whose time zone is UTC */
  isoNow(): string {
    return isoAt(this.nowMs());
  }

  /**
   * Get the current seed value
   */
  getSeed(): number {
    return this.seed;
  }

  /**
   * Create a seeded random number generator
   */
  private createRandomGenerator(seed: number): () => number {
    // Simple xorshift algorithm for deterministic random numbers
    let state = seed;
    return () => {
      state ^= state << 13;
      state ^= state >> 17;
      state ^= state << 5;
      return (state >>> 0) / 4294967296;
    };
  }

  /**
   * Pick a random item from an array
   */
  sample<T>(arr: T[]): T {
    return arr[Math.floor(this.random() * arr.length)];
  }

  /**
   * Pick n unique random items from an array
   */
  sampleSize<T>(arr: T[], n: number): T[] {
    if (n <= 0) return [];
    if (n >= arr.length) return [...arr];
    // Fisher–Yates shuffle on a copy, then slice
    const copy = [...arr];
    for (let i = copy.length - 1; i > 0; i--) {
      const j = Math.floor(this.random() * (i + 1));
      [copy[i], copy[j]] = [copy[j], copy[i]];
    }
    return copy.slice(0, n);
  }

  /**
   * Generate a random integer in a range
   */
  randomInt(min: number, max: number): number {
    return Math.floor(this.random() * (max - min + 1)) + min;
  }

  /**
   * Generate a random float in a range
   */
  randomFloat(min: number, max: number, decimals = 2): number {
    const val = this.random() * (max - min) + min;
    return Number(val.toFixed(decimals));
  }

  /**
   * Generate a random hex string
   */
  randomHex(length: number): string {
    let result = '';
    for (let i = 0; i < length; i++) {
      result += Math.floor(this.random() * 16).toString(16);
    }
    return result;
  }

  /**
   * A random UUID, like Rails' request IDs and ActiveJob's job IDs
   */
  randomUuid(): string {
    const variant = this.sample(['8', '9', 'a', 'b']);
    return `${this.randomHex(8)}-${this.randomHex(4)}-4${this.randomHex(3)}-${variant}${this.randomHex(3)}-${this.randomHex(12)}`;
  }

  /**
   * Generate a random email address (some names have accents)
   */
  randomEmail(): string {
    const firstName = this.sample(SampleData.FIRST_NAMES).toLowerCase();
    const lastName = this.sample(SampleData.LAST_NAMES).toLowerCase();
    const domain = this.sample(SampleData.DOMAINS);
    return `${firstName}.${lastName}@${domain}`;
  }

  /**
   * A password as a user would type it
   */
  randomPassword(): string {
    return `${this.sample(['hunter', 'sunshine', 'correct-horse'])}${this.randomInt(100, 999)}!`;
  }

  /**
   * A test card number that passes the Luhn check, as LogStruct's scrubber needs
   */
  randomCreditCard(): string {
    return this.sample(SampleData.TEST_CARD_NUMBERS);
  }

  /**
   * A US phone number, in a format LogStruct's scrubber matches
   */
  randomPhone(): string {
    return `+1-555-${this.randomInt(200, 999)}-${this.randomInt(1000, 9999)}`;
  }

  /**
   * An IP address from the ranges set aside for documentation
   */
  randomIP(): string {
    return this.sample(SampleData.IP_ADDRESSES);
  }

  /**
   * Generate a random timestamp in ISO format
   */
  randomTimestamp(daysBack = 7): string {
    const past = new Date(this.nowMs() - this.randomInt(0, daysBack * 24 * 60 * 60 * 1000));
    return past.toISOString();
  }

  /**
   * Generate a random path
   */
  randomPath(): string {
    return `${this.sample(SampleData.PATHS)}/${this.randomInt(1, 100)}`;
  }

  /**
   * Generate a random duration in milliseconds
   */
  randomDuration(): number {
    return this.randomFloat(10, 3000, 2);
  }

  /**
   * Generate a random enum value
   */
  randomEnum<T>(enumObj: Record<string, T>): T {
    const keys = Object.keys(enumObj).filter((k) => Number.isNaN(Number(k)));
    const randomKey = this.sample(keys);
    return enumObj[randomKey] as T;
  }
}
