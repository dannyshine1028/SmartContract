# Survicate Recon Notes

## Initial Research
- Program found via user request pointing to huntbug.com/program/survicate
- Listed in HuntBug open directory as "Survicate" (live program)
- Survicate is a customer feedback/survey platform

## Scope (from terms)
Confirmed in-scope:
- Web hosts: panel.survicate.com, panel-api.survicate.com, survey.survicate.com, surveys-static.survicate.com, surveys-static-prd.survicate-cdn.com, respondent.survicate.com
- SDKs: iOS, Android, React Native, Flutter, JavaScript
- Panel: panel.survicate.com
- Data Export API v2 only
- Webhooks

Everything else is out of scope.

## Next Steps
1. Visit in-scope hosts to understand attack surface
2. Look for authentication, API endpoints, business logic
3. Check SDKs if relevant (may need source analysis)
4. Focus on in-scope web properties first
