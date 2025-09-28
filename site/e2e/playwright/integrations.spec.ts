import { test, expect } from '@playwright/test';

test('integrations page shows example logs and code', async ({ page }) => {
  await page.goto('/site/integrations');
  await expect(page.locator('h1')).toContainText('Integrations');
  await expect(
    page.locator('h2:has-text("Example Logs")').first(),
  ).toBeVisible();
  // Ensure at least one rendered code block contains JSON braces after hydration
  const preBlocks = page.locator('pre');
  await expect(preBlocks.first()).toBeVisible();
  const text = await preBlocks.first().textContent();
  expect(text).toBeTruthy();
  expect(String(text)).toContain('{');
});
