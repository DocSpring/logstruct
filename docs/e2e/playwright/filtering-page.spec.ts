import { expect, test } from '@playwright/test';

test('filtering page shows its sections, examples and scrubber table', async ({ page }) => {
  await page.goto('/docs/filtering-sensitive-data');
  await expect(
    page.getByRole('heading', { level: 1, name: /Filtering Sensitive Data/ }),
  ).toBeVisible();

  for (const id of [
    'key-filtering',
    'filtered-values',
    'filtered-keys',
    'rails-filter-parameters',
    'hashed-values',
    'adding-keys',
    'string-scrubbing',
    'scrubbing-limits',
    'custom-string-scrubbing',
    'where-filtering-applies',
    'left-out',
    'large-values',
  ]) {
    await expect(page.locator(`#${id}`)).toBeVisible();
  }

  await expect(page.locator('pre', { hasText: '"_keys_count": 2' }).first()).toBeVisible();
  await expect(page.locator('pre', { hasText: 'filter_keys_with_hashes' }).first()).toBeVisible();

  const table = page.locator('table');
  await expect(table.locator('td', { hasText: /^authorization_credentials/ })).toBeVisible();
  await expect(table.locator('td', { hasText: 'Call [PHONE]' }).first()).toBeVisible();
});
