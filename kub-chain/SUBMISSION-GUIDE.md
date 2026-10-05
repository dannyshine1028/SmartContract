# Submission guide — KUB Chain F3 (bridge NATIVE input-validation)

Program: KUB Chain & Ecosystem → open https://hackenproof.com/programs/kub-chain-and-ecosystem
→ click **Submit report** (requires 100 reputation + KYC — see note at bottom).

## Form field values

- **Target / Asset:**  `https://bridge.kubchain.com`  (Web)
- **Title:**
  `BridgeERC20V3: ERC20 bridge() entry accepts NATIVE_REPRESENTATION, paying out contract-held native with no matching deposit`
- **Severity:**  `Low`  (lowest selectable; triage may close as Informative — that still earns reputation. Do NOT pick higher — there is no profit path.)
- **Vulnerability category:**  closest = **Unsecure Design / Business Logic**
  (maps to the program's in-scope "Smart Contracts — Attacks on logic (behavior differs from business description)")
- **Vulnerability details (body):**  paste the full contents of
  `Result(only BugReport)/kubchain-bridge-erc20-entry-accepts-native-representation.md`
  (it is already in the required 8-section HackenProof format, with the honest severity framing up front).
- **Attachment:**  `Source/kub-chain/kubchain-bridge-native-poc.zip`  (Foundry fork PoC, 4 KB)

## Important honesty notes (keep these in the report — do NOT remove)
- The report states up front this is Informational/Low and NOT theft (no profit path: the contract holds
  0 native, no receive()/fallback()). This framing is deliberate — it keeps the submission credible on a
  strict program and avoids a "no-impact/overclaim" rejection.
- It is a real, reproducible contract defect with a one-line fix. Fair outcomes: Informative (reputation)
  or, less likely, Out-of-scope/no-impact. Neither is a penalty.

## Gate check before submitting
This program requires **100 reputation points + KYC**. Confirm your account meets both, or the submit
button will be blocked. If you are short on reputation, hold this report until you qualify.
