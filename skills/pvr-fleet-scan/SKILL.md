---
name: pvr-fleet-scan
description: Passively scan one or many websites from the outside to find which run a PHP version exposed to the current advisory (PHP2Shell and later). Use for "scan my sites", "check my clients' websites", "which sites are vulnerable", "escanea mis sitios", "revisa los sitios de mis clientes". Produces a color HTML report and CSV, then ranks what to fix first.
---

# Fleet Scan (outside-in, passive)

Read **pvr-navigator** rules first if you have not this session. Authorization gate
applies: confirm the user owns or manages every domain in the list.

## What it does and does not do

- One normal page request per site (like a browser visit). Reads `X-Powered-By`,
  `Server`, cookies and page markup for PHP fingerprints.
- No payloads, no fuzzing, no logins, no port scans. Do not add any.
- It can only see what the server advertises. Hardened sites show **HIDDEN**; that
  is expected and means "confirm on the server", not "safe".

## Steps

1. **Build the target list** as `sites.txt`, one domain or URL per line, `#` for
   comments. Sources: the user's message, a CRM/Notion export, a hosting panel's
   domain list. De-duplicate; include `www.` and apex only if they point to
   different servers.
2. **Run**:
   ```bash
   bash "$PVR/scripts/scan.sh" -f sites.txt -o reports/fleet-$(date +%Y%m%d)
   ```
   Exit code: 0 clear, 1 manual checks needed, 2 at least one site at risk.
3. **Read the CSV** (`reports/fleet-*.csv`), not just the terminal output.
4. **Rank** what to fix first (present as a table, highest first):

   | Priority | Rule |
   |---|---|
   | P1 | EOL or VULNERABLE **and** handles logins, payments or customer data (stores, WooCommerce, Magento, member areas) |
   | P2 | Any other EOL or VULNERABLE |
   | P3 | HIDDEN on a site the user knows is PHP (WordPress etc.) |
   | P4 | CHECK (distro build, confirm backport) |
   | P5 | PATCHED: still confirm processes restarted (pvr-verify-close) |

5. **Hand off**:
   - Has shell access -> pvr-server-audit for that host.
   - Shared/managed hosting -> pvr-client-comms `host-ticket` template.
   - Any P1/P2 that was online on or after `LEAK_DATE` -> also pvr-compromise-check.
6. **Deliver the report**: the HTML file is the visual summary (cards colored by
   status). Share it with the user; for clients, strip internal notes.

## Interpreting edge cases

- **Behind Cloudflare/CDN**: headers usually still pass through from the origin. If
  the result is NO-PHP but the user says it is WordPress, treat it as HIDDEN.
- **CHECK with an Ubuntu/Debian/RHEL suffix**: the version number lags the real
  patch level. Only a package changelog or vendor advisory listing the CVEs
  confirms it (pvr-server-audit does this automatically on the host).
- **Several sites, one server**: patch once, but re-scan every site afterwards; they
  may use different PHP versions via MultiPHP/handlers.
- **ERROR**: retry once with `TIMEOUT=25`. Persistent errors are a DNS/firewall
  question, not a vulnerability verdict.

## Scheduling (optional)

For agencies, a daily re-scan until everything is PATCHED is useful. Use the
harness's scheduler (scheduled task / cron) to run the same command and alert on
exit code 2. Stop the schedule once the fleet is clean for 7 days.
