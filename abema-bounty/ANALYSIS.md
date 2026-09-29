# ABEMA Bug Bounty Program - Initial Analysis

## Overview
- **Platform**: IssueHunt
- **Organization**: CyberAgent, Inc.
- **Program Active**: Since Feb 2025
- **Response Time**: 5 days
- **Total Scope**: Web + Mobile (iOS/Android)

## In-Scope Assets
1. **Web/API Domains**: abema.tv, *.abema.tv, contents-abema.com, *.abema.io, *.abem.io, *.abema-tv.com, *.abema-tv.org
2. **iOS App**: https://apps.apple.com/jp/app/id1074866833
3. **Android App**: https://play.google.com/store/apps/dev?id=6759178670051565700

## Technical Architecture

### API Services
Two distinct API gateways identified:

1. **api.abema.tv** (port 443)
   - Public endpoints (no auth required for some)
   - `/v1/channels` - Returns channel list with live stream URLs
   - CORS: `access-control-allow-origin: *`
   - Rate limiting: 1000 req with X-Ratelimit headers
   - Server: istio-envoy (abema-tv-api-tky cluster)
   - Returns: channel ID, name, live_stream links, thumbnails

2. **api.abema.io** (port 443)
   - Requires Authorization header for most endpoints
   - `/v1/channels` - Returns channel list with playback URLs (HLS/DASH), broadcast region, status, gnid
   - `/v1/access_token` - 401 "authorization header must exist"
   - `/v1/users` - POST endpoint returns "invalid_argument"
   - Server: istio-envoy (abema-gateway-cdn cluster)
   - Has DRM status per channel (some channels have DRM enabled)

### CDN & Media
- **Akamai**: linear-abematv.akamaized.net (live streams)
- **CloudFront**: contents-abema.com (static content)
- **Image CDN**: image.p-c2-x.abema-tv.com

### Authentication
- All endpoints on api.abema.io require Authorization header
- Error messages reveal auth requirement: "authorization header must exist"
- POST /v1/users endpoint exists but requires unknown parameters
- Access tokens likely tied to device registration
- auth.abema.tv exists (IP: 34.149.107.240)

### Geo-Restriction
- abema.tv web returns geo-block error for non-Japan IPs
- Error page: "このサービスはお住まいの地域からはご利用になれません。"
- API endpoints are accessible globally (CORS enabled)

## Potential Attack Surface
1. **Geo-restriction bypass** - API is accessible from any region
2. **Token/auth flow** - Could reveal insecure token handling
3. **Media access controls** - Unauthenticated HLS streams are accessible
4. **IDOR** - Content accessible via numeric/string IDs might be brute-forceable
5. **CORS configuration** - `access-control-allow-origin: *` could enable CSRF-like attacks
6. **Mobile app attack surface** - iOS/Android apps likely use same API

## Notes
- Web UI geo-restricted to Japan, API is globally accessible
- HLS streams are accessible without authentication
- DRM is selectively applied (some channels have DRM, some don't)
- Security headers present but minimal (no CSP, weak HSTS max-age=300)
