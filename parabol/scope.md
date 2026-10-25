# Parabol Bug Bounty Program — Scope

Source: https://huntbug.com/program/parabol

## In-scope assets
- parabol.co (apex)
- action.parabol.co (API subdomain)
- *.parabol.co (all subdomains)

## Out-of-scope assets
- (none explicitly listed in program brief)

## Rules of Engagement
- Test only in-scope assets
- No social engineering, phishing, vishing, pretexting
- No physical access attempts
- No DoS / resource exhaustion / destructive payloads
- No pivoting to third parties not named in scope
- No extortion framing
- Use own accounts only
- Stay within published rate limits
- Report through platform only

## Bounty
- Low: up to $50
- Medium: up to $150
- High: up to $300
- Critical: up to $1,000

## Program type
- Public

## Key endpoints
- GraphQL API: https://action.parabol.co/graphql
- GraphiQL explorer: https://action.parabol.co/graphql (in browser)
- Schema SDL: https://action.parabol.co/graphql/schema.graphql

## Auth
- Personal Access Tokens (PATs), Bearer auth
- 16 scopes: users:read/write, teams:read/write, orgs:read/write, meetings:read/write, tasks:read/write, templates:read/write, pages:read/write, comments:read/write
- Token creation: https://action.parabol.co/me/profile