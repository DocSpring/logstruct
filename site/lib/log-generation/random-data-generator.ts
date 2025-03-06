import { SampleData } from "./sample-data";

/**
 * Utility for generating random data with seed support
 */
export class RandomDataGenerator {
  private seed: number;
  protected random: () => number;

  constructor(seed?: number) {
    this.seed = seed || Math.floor(Math.random() * 1000000);
    this.random = this.createRandomGenerator(this.seed);
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
    let result = "";
    for (let i = 0; i < length; i++) {
      result += Math.floor(this.random() * 16).toString(16);
    }
    return result;
  }

  /**
   * Generate a random email address
   * 
   * @param filtered Whether to return a filtered format with [EMAIL:hash] syntax
   * @param useObjectFormat Whether to use the _filtered object format
   */
  randomEmail(filtered = false, useObjectFormat = false): string | object {
    const emailHash = this.randomHex(6);
    
    if (filtered) {
      if (useObjectFormat) {
        // Return the object format with _filtered property
        return {
          _filtered: {
            _class: "String",
            _bytes: 24 + this.randomInt(0, 10), // Randomize byte size a bit
            _hash: emailHash
          }
        };
      } else {
        // Return the simple [EMAIL:hash] format
        return `[EMAIL:${emailHash}]`;
      }
    }
    
    // Return an actual (fake) email address
    const firstName = this.sample(SampleData.FIRST_NAMES).toLowerCase();
    const lastName = this.sample(SampleData.LAST_NAMES).toLowerCase();
    const domain = this.sample(SampleData.DOMAINS);
    return `${firstName}.${lastName}@${domain}`;
  }
  
  /**
   * Generate a filtered password
   */
  randomPassword(filtered = true): string {
    if (filtered) {
      return "[PASSWORD]";
    }
    return `password${this.randomInt(100, 999)}!`;
  }
  
  /**
   * Generate a filtered credit card number
   */
  randomCreditCard(filtered = true): string {
    if (filtered) {
      return "[CREDIT_CARD]";
    }
    return `${this.randomInt(1000, 9999)}-${this.randomInt(1000, 9999)}-${this.randomInt(1000, 9999)}-${this.randomInt(1000, 9999)}`;
  }
  
  /**
   * Generate a filtered phone number
   */
  randomPhone(filtered = true): string {
    if (filtered) {
      return "[PHONE]";
    }
    return `+1-${this.randomInt(100, 999)}-${this.randomInt(100, 999)}-${this.randomInt(1000, 9999)}`;
  }
  
  /**
   * Generate a filtered IP address
   */
  randomIP(filtered = false): string {
    if (filtered) {
      return "[IP]";
    }
    return this.sample(SampleData.IP_ADDRESSES);
  }
  
  /**
   * Generate a filtered hash (for nested objects that contain sensitive data)
   */
  filteredHash(sensitivity: 'password' | 'pii' | 'json' = 'json'): object {
    let keys: string[];
    
    switch (sensitivity) {
      case 'password':
        keys = ["password", "password_confirmation", "current_password", "token"];
        break;
      case 'pii':
        keys = ["ssn", "tax_id", "credit_card", "phone", "address"];
        break;
      default: // json
        keys = ["data", "payload", "attributes", "request_body"];
    }
    
    return {
      _filtered: {
        _class: "Hash",
        _keys_count: keys.length,
        _keys: keys,
        _bytes: this.randomInt(20, 500)
      }
    };
  }
  
  /**
   * Generate a filtered array
   */
  filteredArray(itemCount: number = 0): object {
    if (itemCount === 0) {
      itemCount = this.randomInt(3, 20);
    }
    
    return {
      _filtered: {
        _class: "Array",
        _length: itemCount,
        _bytes: itemCount * this.randomInt(10, 50)
      }
    };
  }

  /**
   * Generate a random timestamp in ISO format
   */
  randomTimestamp(daysBack = 7): string {
    const now = new Date();
    const past = new Date(
      now.getTime() - this.randomInt(0, daysBack * 24 * 60 * 60 * 1000)
    );
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
    const keys = Object.keys(enumObj).filter(k => isNaN(Number(k)));
    const randomKey = this.sample(keys);
    return enumObj[randomKey] as T;
  }
}