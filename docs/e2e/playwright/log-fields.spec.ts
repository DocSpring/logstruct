import { expect, test } from '@playwright/test';

test('log fields page lists the keys, the short names and an example line per log type', async ({
  page,
}) => {
  await page.goto('/docs/log-fields');
  await expect(page.getByRole('heading', { level: 1, name: /Log Fields/ })).toBeVisible();

  for (const id of ['common-keys', 'context-keys', 'short-names', 'example-lines', 'truncation']) {
    await expect(page.locator(`#${id}`)).toBeVisible();
  }

  const table = page.getByTestId('log-field-table');
  const mailerRow = table.locator('tr', { has: page.locator('td', { hasText: /^MailerClass$/ }) });
  await expect(mailerRow.locator('td').first()).toHaveText('mailer');
  const databaseRow = table.locator('tr', { has: page.locator('td', { hasText: /^Database$/ }) });
  await expect(databaseRow).toContainText('Log::Request');

  const request = page.locator('details', { hasText: 'Log::Request' }).first();
  await request.locator('summary').click();
  await expect(request.locator('pre')).toContainText('"req_id"');
  await expect(request.locator('pre')).toContainText('"[FILTERED]"');
});
