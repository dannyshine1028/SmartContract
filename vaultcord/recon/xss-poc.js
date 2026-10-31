const puppeteer = require('puppeteer');
const UA = 'Mozilla/5.0 ResponsibleReporter Gecko/20100101';
const target = process.env.TARGET;
(async () => {
  const browser = await puppeteer.launch({
    executablePath: '/usr/bin/google-chrome',
    headless: 'new',
    userDataDir: '/tmp/vc-poc-' + Date.now(),
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-blink-features=AutomationControlled', '--disable-dev-shm-usage', '--window-size=1280,800'],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 800 });
  await page.setUserAgent(UA);
  await page.setExtraHTTPHeaders({
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Referer': 'https://vaultcord.com/',
    'Origin': 'https://vaultcord.com',
  });
  const resp = await page.goto(target, { waitUntil: 'domcontentloaded', timeout: 60000 });
  console.log('HTTP', resp && resp.status(), 'URL', page.url());
  await new Promise(r => setTimeout(r, 4000));
  console.log('BEFORE body=', (await page.evaluate(() => document.body.innerText.slice(0,120))).replace(/\n/g,' | '));
  await new Promise(r => setTimeout(r, 60000));
  console.log('AFTER title=', JSON.stringify(await page.title()));
  console.log('AFTER domain=', await page.evaluate(() => document.domain).catch(e=>'err'));
  console.log('AFTER body=', (await page.evaluate(() => document.body.innerText.slice(0,200))).replace(/\n/g,' | '));
  await page.screenshot({ path: '/home/user/Documents/Work/Guk/3.BugBounty/Source/vaultcord/evidence/xss-poc.png' });
  await browser.close();
})().catch(e => { console.error('FATAL', e.message); process.exit(1); });
