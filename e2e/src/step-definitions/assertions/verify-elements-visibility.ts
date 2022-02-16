import { Then } from '@cucumber/cucumber';
import { expect } from '@playwright/test';

Then(
  /^I should see "([^"]*)" text$/,
  async function(text: string) {

    const locator = await global.page.locator(`text=${text}`);

    await expect(locator).toBeVisible();
  }
);

Then(
  /^I should see a button with "([^"]*)" text$/,
  async function(text: string) {

    const locator = await global.page.locator(`button >> text=${text}`);

    await expect(locator).toBeVisible();
  }
);

