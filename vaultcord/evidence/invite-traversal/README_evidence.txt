Evidence archive — VaultCord marketplace invite path traversal
================================================================

Submitted with the BugBase report for https://bugbase.ai/programs/vaultcord
(finding: unauthenticated path traversal in api.vaultcord.com/market/invites).
The vulnerability was fixed during testing, before this report was filed.

Files
-----
01_baseline_invite_verify_20261031.txt
    Live re-test (2026-10-31): legitimate invite code "python" still resolves
    (HTTP 200, public Discord invite JSON) — endpoint is alive and the check is
    code-specific, not a blanket shutdown.

02..07_traversal_rejected_20261031.txt
    Live re-test (2026-10-31): traversal/encoding variants (..%2F, %2e%2e%2f,
    double-encoded %252F, %5C, ....%2F%2F, nested) all return
    HTTP 400 {"success":false,"message":"Invalid invite code"} — the fix
    rejects anything outside an alphanumeric/dash allowlist.

08_historical_exploit_outputs_20261030_transcribed.txt
    The original exploit responses (bot account object, application config with
    owner identity, gateway session limits), transcribed from the 2026-10-30
    live test log. Raw capture files were not retained on disk; this file is a
    faithful transcription, clearly labelled as historical and not re-runnable
    after the fix.

Provenance / testing details
----------------------------
- Target: https://api.vaultcord.com (in-scope asset), endpoint
  GET /market/invites/{code}.
- Traffic used the required User-Agent
  "Mozilla/5.0 ResponsibleReporter Gecko/20100101" for the 2026-10-31 re-tests;
  the 2026-10-30 test used a standard browser UA plus Referer (the app-level
  WAF gate). No cookies, tokens or accounts were used.
- No other users' data was accessed; only the service's own bot identity and
  application configuration were returned.
- The service's bot token was usable by unauthenticated third parties during
  the exposure window. Rotating that token is advisable even though the
  endpoint now rejects traversal.
