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

test('on a phone the docs menu is closed until opened, and closes on the next page', async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/docs/logging');
  const menu = page.getByRole('button', { name: 'Documentation menu' });
  const troubleshooting = page
    .locator('#docs-sidebar')
    .getByRole('link', { name: 'Troubleshooting' });

  await expect(page.locator('h1')).toBeInViewport();
  await expect(troubleshooting).toBeHidden();

  await menu.click();
  await expect(menu).toHaveAttribute('aria-expanded', 'true');
  await troubleshooting.click();

  await expect(page.locator('h1')).toContainText('Troubleshooting');
  await expect(menu).toHaveAttribute('aria-expanded', 'false');
  await expect(troubleshooting).toBeHidden();
});

test('on a desktop the docs menu is always open', async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 900 });
  await page.goto('/docs/logging');

  await expect(page.getByRole('button', { name: 'Documentation menu' })).toBeHidden();
  await expect(
    page.locator('#docs-sidebar').getByRole('link', { name: 'Troubleshooting' }),
  ).toBeVisible();
});
