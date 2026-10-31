const puppeteer = require('puppeteer');
const UA = 'Mozilla/5.0 ResponsibleReporter Gecko/20100101';
const target = process.env.TARGET;
(async () => {
  const browser = await puppeteer.launch({
    executablePath: '/usr/bin/google-chrome',
    headless: 'new',
    userDataDir: '/tmp/vc-profile-' + Date.now(),
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-blink-features=AutomationControlled', '--disable-dev-shm-usage'],
  });
  const page = await browser.newPage();
  await page.setUserAgent(UA);
  await page.setExtraHTTPHeaders({
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Referer': 'https://vaultcord.com/',
    'Origin': 'https://vaultcord.com',
  });
  let dialogs = [];
  page.on('dialog', async d => { dialogs.push(d.message()); await d.dismiss(); });
  let resp;
  try {
    resp = await page.goto(target, { waitUntil: 'domcontentloaded', timeout: 60000 });
    console.log('HTTP', resp && resp.status(), 'URL', page.url());
  } catch (e) { console.log('NAV-ERR', e.message); }
  await new Promise(r => setTimeout(r, 3000));
  console.log('BEFORE title=', JSON.stringify(await page.title()), 'pwned=', await page.evaluate(() => window.__pwned || null).catch(e=>'evalerr'));
  console.log('BEFORE body=', (await page.evaluate(() => document.body ? document.body.innerText.slice(0,150) : '')).replace(/\n/g,' | '));
  await new Promise(r => setTimeout(r, 60000));
  console.log('AFTER title=', JSON.stringify(await page.title().catch(e=>'err')));
  console.log('AFTER pwned=', await page.evaluate(() => window.__pwned || null).catch(e=>'evalerr'));
  console.log('AFTER href=', await page.evaluate(() => location.href).catch(e=>'evalerr'));
  console.log('DIALOGS=', JSON.stringify(dialogs));
  await browser.close();
})().catch(e => { console.error('FATAL', e.message); process.exit(1); });
