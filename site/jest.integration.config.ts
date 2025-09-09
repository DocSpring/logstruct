import type { Config } from 'jest';

const config: Config = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['**/e2e/**/*.test.(ts|js)'],
  verbose: true,
  // Integration tests can be slower due to build/start
  testTimeout: 120000,
};

export default config;
