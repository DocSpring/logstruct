import type { PlaywrightTestConfig } from '@playwright/test';

const PORT = process.env.PORT ? Number(process.env.PORT) : 3011;

const config: PlaywrightTestConfig = {
  timeout: 30_000,
  webServer: {
    command: 'node scripts/serve-static.js',
    port: PORT,
    reuseExistingServer: true,
    env: { PORT: String(PORT) },
  },
  use: {
    baseURL: `http://localhost:${PORT}`,
    headless: true,
  },
  testDir: 'e2e/playwright',
};

export default config;
