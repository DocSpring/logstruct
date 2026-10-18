import { expect, test } from '@playwright/test';

// Each integration page's h1 and one of its section headings
const pages = [
  { path: '/docs/integrations/sidekiq', title: 'Sidekiq', section: 'h3:has-text("Failed jobs")' },
  {
    path: '/docs/integrations/good-job',
    title: 'GoodJob',
    section: 'h3:has-text("Thread errors")',
  },
  {
    path: '/docs/integrations/active-job',
    title: 'ActiveJob',
    section: 'h2:has-text("Not logged")',
  },
  {
    path: '/docs/integrations/action-mailer',
    title: 'ActionMailer',
    section: 'h2:has-text("Error handlers")',
  },
  { path: '/docs/integrations/sql', title: 'SQL Queries', section: 'h2:has-text("Bind values")' },
  {
    path: '/docs/integrations/security',
    title: 'Security Lines',
    section: 'h2:has-text("IP spoofing")',
  },
];

for (const { path, title, section } of pages) {
  test(`${path} renders`, async ({ page }) => {
    await page.goto(path);
    await expect(page.locator('h1')).toContainText(title);
    await expect(page.locator(section).first()).toBeVisible();
  });
}
