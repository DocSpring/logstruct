import { SampleData } from "./sample-data";
import logTypeData from "./log-types.json";

/**
 * Utility for generating random log data with seed support
 */
export class LogGenerator {
  private seed: number;
  private random: () => number;

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
   */
  randomEmail(filtered = false): string {
    if (filtered) {
      return `[EMAIL:${this.randomHex(6)}]`;
    }
    const firstName = this.sample(SampleData.FIRST_NAMES).toLowerCase();
    const lastName = this.sample(SampleData.LAST_NAMES).toLowerCase();
    const domain = this.sample(SampleData.DOMAINS);
    return `${firstName}.${lastName}@${domain}`;
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
   * Generate a random log of a given type
   */
  generateLog(logType: string): Record<string, any> {
    // Get the log structure from the exported data
    const logStructure = (logTypeData as any).logs[logType];
    if (!logStructure) {
      throw new Error(`Unknown log type: ${logType}`);
    }

    // Create a log with common fields
    const log: Record<string, any> = {
      timestamp: this.randomTimestamp(),
      level: this.sample((logTypeData as any).enums.LogLevel),
      source: this.sample((logTypeData as any).enums.Source),
      event: this.sample((logTypeData as any).enums.LogEvent),
    };

    // Add fields based on their types
    const fields = logStructure.fields;
    Object.entries(fields).forEach(([fieldName, fieldInfo]: [string, any]) => {
      // Skip if it's a common field we already set
      if (["timestamp", "level", "source", "event"].includes(fieldName)) {
        return;
      }

      // Skip optional fields sometimes
      if (fieldInfo.optional && this.random() < 0.3) {
        return;
      }

      // Generate value based on field type
      switch (fieldInfo.type) {
        case "string":
          if (fieldName === "method") {
            log[fieldName] = this.sample(SampleData.HTTP_METHODS);
          } else if (fieldName === "path") {
            log[fieldName] = this.randomPath();
          } else if (fieldName === "controller") {
            log[fieldName] = this.sample(SampleData.CONTROLLERS);
          } else if (fieldName === "action") {
            log[fieldName] = this.sample(SampleData.ACTIONS);
          } else if (fieldInfo.format === "date-time") {
            log[fieldName] = this.randomTimestamp();
          } else {
            log[fieldName] = `${fieldName}_${this.randomHex(4)}`;
          }
          break;
        case "integer":
          if (fieldName === "status") {
            log[fieldName] = this.sample(SampleData.STATUS_CODES);
          } else {
            log[fieldName] = this.randomInt(1, 1000);
          }
          break;
        case "number":
          if (fieldName === "duration") {
            log[fieldName] = this.randomDuration();
          } else {
            log[fieldName] = this.randomFloat(0, 100);
          }
          break;
        case "boolean":
          log[fieldName] = this.random() > 0.5;
          break;
        case "array":
          log[fieldName] = Array(this.randomInt(1, 3))
            .fill(0)
            .map(() => `item_${this.randomHex(4)}`);
          break;
        case "object":
          log[fieldName] = {
            key1: `value_${this.randomHex(4)}`,
            key2: this.randomInt(1, 100),
          };
          break;
        case "enum":
          if (fieldInfo.values === "LogLevel") {
            log[fieldName] = this.sample((logTypeData as any).enums.LogLevel);
          } else if (fieldInfo.values === "Source") {
            log[fieldName] = this.sample((logTypeData as any).enums.Source);
          } else if (fieldInfo.values === "LogEvent") {
            log[fieldName] = this.sample((logTypeData as any).enums.LogEvent);
          }
          break;
      }
    });

    return log;
  }

  /**
   * Generate a sequence of logs that tell a story
   * For example: job enqueue -> start -> finish
   */
  generateJobSequence(): Record<string, any>[] {
    const jobId = this.randomHex(8);
    const jobClass = this.sample(SampleData.JOB_CLASSES);
    const queueName = ["default", "critical", "low", "mailers"][
      this.randomInt(0, 3)
    ];
    const args = [
      this.randomInt(1, 100),
      { action: this.sample(["create", "update", "process"]) },
    ];

    // Enqueue event
    const enqueueLog = {
      timestamp: this.randomTimestamp(),
      level: "info",
      source: "job",
      event: "enqueue",
      job_id: jobId,
      job_class: jobClass,
      queue_name: queueName,
      arguments: args,
    };

    // Start event (happens a little later)
    const startTime = new Date(
      new Date(enqueueLog.timestamp).getTime() + this.randomInt(100, 5000)
    );
    const startLog = {
      timestamp: startTime.toISOString(),
      level: "info",
      source: "job",
      event: "start",
      job_id: jobId,
      job_class: jobClass,
      queue_name: queueName,
      arguments: args,
    };

    // Finish event (with duration)
    const duration = this.randomFloat(50, 2000);
    const finishTime = new Date(startTime.getTime() + duration);
    const finishLog = {
      timestamp: finishTime.toISOString(),
      level: "info",
      source: "job",
      event: "finish",
      job_id: jobId,
      job_class: jobClass,
      queue_name: queueName,
      arguments: args,
      duration: duration,
    };

    return [enqueueLog, startLog, finishLog];
  }
}
