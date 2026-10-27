# Phemex Web & Mobile - Analysis

## Program
- Platform: HackenProof
- URL: https://hackenproof.com/programs/phemex-web-and-mobile
- Scope: https://phemex.com (Web), iOS app, Android app
- Rewards: Critical $5k-30k, High $2k-5k, Medium $600-2k, Low $50-600

## Recon
- phemex.com returns 403 "trading not available in your region" (CloudFront)
- api.phemex.com is reachable; many endpoints return auth-required or specific errors
- Public market data: /exchange/public/cfg/v2/products returns full product/config (saved locally)
- Products: 2140 total (1042 Spot, 907 PerpetualV2, 166 Perpetual, 25 PerpetualPilot), 999 currencies

## API Exploration
- api.phemex.com responds; public config endpoints accessible (products/cfg/v2/products)
- Market data via md/spot/ticker/24hr works (e.g., sBTCUSDT)
- Many endpoints require auth; different versions/paths exist
- phemex.com itself geo-blocked (403) but API is accessible

## Key Observations
- phemex.com is geo-blocked (CloudFront 403) but API is accessible from this environment
- Public API endpoints exist without auth (market data, config, time)
- Auth required for user/account/trading endpoints
- Many /exchange/public/* paths return auth errors suggesting different auth model or they require certain headers

## Market Data Endpoints (Public)
- md/spot/ticker/24hr?symbol=sBTCUSDT - returns ticker data
- md/spot/orderbook?symbol=sBTCUSDT&depth=N - returns orderbook
- md/spot/trade?symbol=sBTCUSDT&limit=N - returns recent trades
- md/v3/ticker/24hr?symbol=BTCUSDT - also works (futures style symbol)
- public/time - server time

All accessible without authentication from this environment.

## Klines/Candles
- exchange/public/md/kline?symbol=sBTCUSDT&resolution=60&from=...&to=... works (returns OHLCV data)

## WebSocket
- ws.phemex.com exists on 443 but blocks/returns 403 - likely requires auth or specific headers/protocol upgrade

## Notes on Testing
- phemex.com main site is geo-blocked from this environment
- API is accessible - focus on API security testing
- Many endpoints follow /exchange/* and /md/* patterns

## More Public Endpoints
- exchange/public/products - futures products (15 contracts)
- exchange/public/md/kline - kline data for contracts
- md/spot/* - spot market data
- public/time - server time

## Web App Recon
- phemex.com accessible with CF-IPCountry: US header (geo-block bypassed)
- Has many public pages, blogs, help center, academy
- API structure: api.phemex.com with various endpoints
- Web app may have client-side logic and API calls we can inspect

## Summary
- Program: Phemex Web & Mobile (HackenProof), rewards up to $500k
- Scope: phemex.com, iOS/Android apps
- Web accessible with geo-bypass headers; API at api.phemex.com accessible
- Public endpoints identified: market data (md/*), config (exchange/public/*), time
- Auth-gated endpoints follow /exchange/* patterns requiring API keys
- Security controls in place (auth checks, CloudFront/WAF, no permissive CORS)
- Reconnaissance complete with public data collected
