### At Acko, Security is the Top Priority!

We put a lot of effort into our application, infrastructure, and processes to ensure that Acko is safe and secure for our customers to buy and claim policies online. Acko’s security team works hard to keep customer data secure.

If you are a bug hunter, security researcher, or white-hat hacker who can identify potential security vulnerabilities, we invite you to test your skills and get recognized or rewarded through our vulnerability disclosure program.

If you think you can find security issues that have the potential to be exploited, we appreciate your help in letting us know as soon as possible.


---

### Disclosure Process

We believe responsible disclosure of any security vulnerabilities identified by security researchers is an essential part of our commitment to ensure stringent quality standards for the security of our systems. This Responsible Disclosure Policy is intended to give security researchers clear guidelines for conducting vulnerability discovery activities and to convey our preferences in how to submit discovered vulnerabilities to us.

`Please always ensure to avoid any privacy violations, degradation of user experience, disruption to production systems, and destruction or manipulation of data.`

Please only use exploits to the extent necessary to confirm the presence of any real or potential security vulnerability and do not use an exploit to compromise or exfiltrate data, establish persistent command-line access, or use the exploit to pivot to other systems.

Please do not report any security vulnerabilities through public channels or to any third parties without our prior written consent. Instead, please report them to the Acko Responsible Disclosure program on BugBase.


---

### Vulnerability Types We Accept

As an insurance company, Acko is particularly focused on vulnerabilities that could lead to `Personal Identifiable Information (PII)` and `KYC data exposure`. We accept the following types of critical security issues:

- Remote Code Execution (RCE), Server Side Request Forgery (SSRF), SQL Injection
- Authentication and Authorization Bypass - leading to unauthorized access to customer accounts or admin panels
- Insecure Direct Object Reference (IDOR) - exposing customer PII, KYC data, or policy documents
- Cross-Site Scripting (XSS) that can steal customer session tokens or sensitive information
- Cross-Site Request Forgery (CSRF) on critical actions affecting customer accounts or financial transactions
- Vulnerabilities leading to bulk customer data exposure - PII, KYC documents, policy records, or financial information


---

### Eligibility

- Employees or their relatives, as well as Acko’s business partners, are not eligible for the bug bounty program.
- Ex-employees can report bugs only after at least 2 years from separation.
- Only the first researcher to report the issue will be eligible for the reward; duplicate submissions of the same bug will not receive any reward.
 

---

### Rules of Engagement

- To ensure a successful bug bounty program, please adhere to the following guidelines:
- Do not violate user privacy, destroy data, or disrupt Acko services
- Do not disclose or share any reported vulnerabilities before resolution
- Only target systems and assets within the defined scope
- Provide clear and detailed reports, including steps to reproduce and methodology of the vulnerability being reported. 
- Do not perform any attack that could harm the reliability, integrity, and capacity of our services. 
- DDoS/spam attacks are not allowed
- Do not exploit the vulnerability by unnecessarily copying, deleting, adapting, viewing data or downloading more data than is necessary to demonstrate the vulnerability
- Do not use attacks on physical security, social engineering, distributed denial of service, spam, or third-party applications
- Immediately erase all obtained/exfiltrated data as soon as it is reported
- Public disclosure of any bug is prohibited. Without express consent of Acko, fixed bugs will not be disclosed
- If any privacy violation is inadvertently caused by researchers while testing, they are liable to disclose it immediately to us
- Exploiting vulnerability for own or others benefit would be considered as an attack to Acko's website, infrastructure and services for which Acko holds rights to take legal actions
- Acko will not be responsible for non-adherence or violation of laws and regulations/norms
- Acko only gives rewards/recognition in the form of Amazon Vouchers. Rewards/Recognition will only be given based on the criticality of the vulnerability. Acko reserves its absolute right to define the criticality of the vulnerability and alter/update the program detail without any prior notice
- Bug disclosure communications with Acko's Security Team are to remain confidential. 
- Researchers must destroy all artifacts created to document vulnerabilities (POC code, videos, screenshots) after the bug report is closed


---

### Reward Guidelines

Our security team assesses the severity of reported vulnerabilities individually to decide the appropriate reward

| Severity | Amazon Voucher Reward |
|--------|--------|
| Critical | ₹ 15,000 |
| High | ₹ 10,000 |
| Medium | No Bounty |
| Low | No Bounty |



All valid security bugs qualify for rewards based on the severity of the identified bug. The severity of the bug, and the corresponding monetary reward/recognition depends on overall business risk, real-world exploitability, impact to customers, exposure scope, and existing mitigation controls.

---


### Response Timeline

- **Initial Acknowledgment:** Within 24 business hours for critical vulnerabilities and 72 business hours for others  
- **Validation:** Up to 7 business days for most vulnerabilities  
- **Reward Processing:** Initiated immediately once the report is triaged and validated; may take up to 30 business days  
- **Fix Implementation:** 30–60 days after validation, based on the criticality and impact
---


### Targets Out of Scope
The following targets are considered out of scope:

- Any subdomains of acko.com unless mentioned "in-scope"
- All sandbox and staging environments
- All external services/software not managed or controlled by Acko
- Third-party applications integrated with Acko platform


---
### Out of Scope
The following issues are considered out of scope:
### Web Application

- Self-XSS that cannot be used to exploit other users
- Attacks requiring Man-in-the-Middle (MITM), physical access to a user's device, or social engineering
- Missing security headers (X-Frame-Options, X-XSS-Protection, Content-Security-Policy, etc.) and cookie flags (Secure, HttpOnly, SameSite)
- Missing best practices related to password policy, account lockout policies, session timeout issues
- Automated scanner-generated reports (e.g. Nuclei, ZAP, Burpscan, Nessus reports, etc.)
- Tabnabbing, Clickjacking, and UI redressing attacks without demonstrable impact
- Email spoofing issues, SPF, DMARC, DKIM configuration problems
- Content Spoofing, Text injection, CSV injection, and Hyperlink injection without showing security impact
- SSL/TLS configuration issues (weak cipher suites, BEAST, BREACH, POODLE attacks)
- Information disclosure (Banner grabbing, Version disclosure, Path disclosure, Server information) without proven impact
- UserId enumeration, email enumeration, and directory listing without sensitive file exposure
- HTTP Request smuggling without proven impact
- API key disclosure, Hardcoded secrets without proven security impact
- Exif data issues, Verbose error messages without sensitive information disclosure
- Rate limiting, Brute force attacks on forms with standard protections
- Open redirects without proven token/credential theft capability
- CORS misconfiguration on non-sensitive endpoints
- CSRF tokens missing on non-sensitive forms (contact forms, newsletters, login-logout CSRF)
- Blind SSRF without proven business impact (pingbacks are not sufficient)
- Homograph attacks and XMLRPC enabled
- Sessions not being invalidated (logout, enabling 2FA, etc.)
- Known CVE vulnerabilities without proper proof of exploitability
- Leaked credentials in dark web, keylogger/sniffer collected passwords, or breached password databases
- Use of known-vulnerable libraries without proven exploitability
- Issues in third-party applications or services not controlled by Acko
- Denial of Service (DoS), Distributed Denial of Service (DDoS), and Physical security testing

### Mobile Application

- Attacks requiring physical access, rooted/jailbroken device access
- Absence of certificate pinning, root/jailbreak detection
- API key leakage, Hardcoded secrets used for non-sensitive activities without proven impact
- Binary protection issues (lack of code obfuscation, debugging enabled in production)
- Data storage and backup issues (backup flag enabled, insecure data storage in logs/cache/temp files)
- UI security issues (screenshot/screen recording allowed, copy/paste in sensitive fields, tapjacking attacks)
- Transport and communication issues (App Transport Security bypass, insecure inter-process communication)
- Weak cryptographic implementations, URL scheme hijacking without demonstrable exploit
- Third-party vulnerabilities (malicious keyboard vulnerabilities, insufficient transport layer protection on non-sensitive data)
- Client-side injection without server-side impact


---


### Contact Information
For any questions regarding this policy or the bug bounty program, please reach out to us at bugbounty@acko.com

**Note:** Submissions are only eligible for validation when submitted through our official bug bounty platform on BugBase. Any submissions via email or alternative communication sources will not be considered.

*Acko reserves the right to change the content of this Policy from time to time or to terminate the Policy at any time.*