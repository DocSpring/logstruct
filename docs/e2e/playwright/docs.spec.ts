import { expect, test } from '@playwright/test';

test('/docs renders', async ({ page }) => {
  await page.goto('/docs');
  await expect(page.locator('h1')).toContainText('Introduction');
  await expect(page.locator('text=Features')).toBeVisible();
});

test('/docs/logging renders custom content', async ({ page }) => {
  await page.goto('/docs/logging');
  await expect(page.locator('h1')).toContainText('Logging to STDOUT');
  await expect(page.locator('text=Rails Defaults vs. LogStruct')).toBeVisible();
});
