// Persona UI login for the Playwright browser MCP (run it with the tool's "run code" action).
// Copy to a git-ignored folder, e.g. .playwright-login/<persona>.js, and fill in the three constants.
async (page) => {
  const ORG = 'https://<mydomain>--<sandbox>.sandbox.my.salesforce.com';
  const USER = '<username>';
  const PASS = '<password>';

  page.on('dialog', d => d.accept().catch(() => {}));
  await page.goto(ORG + '/secur/logout.jsp').catch(() => {});
  await page.waitForTimeout(2500);
  await page.goto(ORG + '/');
  await page.waitForTimeout(2500);

  await page.locator('input[type=email], #username, input[name=username]').first().fill(USER);
  // Some orgs ask for the username first (Next), others show both fields at once.
  if (!(await page.locator('input[type=password]').first().isVisible().catch(() => false))) {
    await page.getByRole('button', { name: /Next|Continue|Log In to Sandbox/i }).first().click();
    await page.waitForTimeout(3500);
  }
  await page.locator('input[type=password]').first().fill(PASS);
  await page.getByRole('button', { name: /Log In|Login/i }).first().click();
  await page.waitForTimeout(8000);

  // Password-expiry prompt: Cancel continues with the current password.
  if (/Change Your Password/i.test(await page.locator('body').innerText())) {
    await page.getByRole('button', { name: /Cancel/i }).first().click().catch(() => {});
    await page.waitForTimeout(5000);
  }
  if (/Verify Your Identity|Register Your Mobile|passkey/i.test(await page.locator('body').innerText())) {
    return 'BLOCKED by identity verification - ask the user';
  }
  return 'logged in as ' + USER + ' -> ' + page.url();
}
