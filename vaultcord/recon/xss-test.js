const puppeteer = require('puppeteer');

const UA = 'Mozilla/5.0 ResponsibleReporter Gecko/20100101';
const target = process.env.TARGET;

(async () => {
  const browser = await puppeteer.launch({
    executablePath: '/usr/bin/google-chrome',
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-blink-features=AutomationControlled', '--disable-dev-shm-usage'],
  });
  const page = await browser.newPage();
  await page.setUserAgent(UA);
  let dialogs = [];
  page.on('dialog', async d => { dialogs.push(d.message()); await d.dismiss(); });
  let navs = [];
  page.on('framenavigated', f => { if (f === page.mainFrame()) navs.push(f.url()); });
  page.on('console', m => { if (m.type() === 'error') console.log('CONSOLE-ERR:', m.text().slice(0,200)); });

  let resp;
  try {
    resp = await page.goto(target, { waitUntil: 'domcontentloaded', timeout: 60000 });
    console.log('HTTP', resp && resp.status(), 'URL', page.url());
  } catch (e) {
    console.log('NAV-ERR', e.message);
  }
  await new Promise(r => setTimeout(r, 2000));
  console.log('BEFORE title=', JSON.stringify(await page.title()));
  console.log('BEFORE pwned=', await page.evaluate(() => window.__pwned || null).catch(e => 'evalerr:' + e.message));
  // wait past 55s countdown
  await new Promise(r => setTimeout(r, 62000));
  const title = await page.title().catch(e => 'err:' + e.message);
  const pwned = await page.evaluate(() => window.__pwned || null).catch(e => 'evalerr:' + e.message);
  const href = await page.evaluate(() => location.href).catch(e => 'evalerr:' + e.message);
  console.log('AFTER title=', JSON.stringify(title));
  console.log('AFTER pwned=', pwned);
  console.log('AFTER href=', href);
  console.log('DIALOGS=', JSON.stringify(dialogs));
  console.log('NAVS=', JSON.stringify(navs));
  await browser.close();
})().catch(e => { console.error('FATAL', e); process.exit(1); });
