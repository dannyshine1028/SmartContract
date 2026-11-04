# Survicate — Findings

## Recon Summary
- In-scope hosts (per program terms): panel.survicate.com, panel-api.survicate.com, survey.survicate.com, surveys-static.survicate.com, surveys-static-prd.survicate-cdn.com, respondent.survicate.com
- In-scope components: iOS/Android/React Native/Flutter/JavaScript SDKs, Panel (panel.survicate.com), Data Export API v2 only, Webhooks
- Program on HuntBug (requires auth to view full details)

## Observations
- panel.survicate.com serves the SPA (login panel). Protected by AWS WAF/CloudFront challenge in some cases.
- panel-api.survicate.com returns 404 to unauthenticated direct requests (no obvious public API).
- respondent.survicate.com returns `{"message":"Missing Authentication Token"}` (auth-gated API).
- survey.survicate.com redirects to survicate.com (marketing).
- Static assets served from CDNs.

## Potential Attack Vectors (to investigate)
1. **Authentication/Authorization** - If we can access panel, look for IDOR, privilege escalation
2. **Data Export API v2** - In scope but may need auth/keys
3. **Webhooks** - In scope, need to understand configuration
4. **SDK security issues** - May be relevant if we can access SDK code
5. **Business logic** - Survey creation, response collection, etc.

## Testing Limitations
- No credentials available
- API endpoints appear auth-protected
- Many hosts return auth errors without valid tokens

## Conclusion
Basic reconnaissance shows auth-protected attack surface. Without credentials, deeper testing (IDOR, business logic flaws) is limited. Need valid test account to proceed with meaningful exploitation attempts.
