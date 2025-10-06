import { expect, test } from '@playwright/test';

test('home page renders and has CTA', async ({ page }) => {
  await page.goto('/');
  await expect(page.locator('h1')).toContainText('Zero-config JSON logging');
  await expect(page.getByRole('link', { name: 'Get Started' })).toBeVisible();
});
