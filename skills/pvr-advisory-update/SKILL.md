---
name: pvr-advisory-update
description: Create or refresh the advisory file that drives every pvr-* script (fixed versions, CVEs, EOL cutoff, dates, mitigations) from official sources. Use when a new PHP vulnerability is announced, when the advisory is older than 7 days, or for "new PHP CVE", "update the advisory", "nueva vulnerabilidad de PHP", "actualiza el advisory".
---

# Advisory Update

The advisory file is the single source of truth. A wrong fixed version here makes
every scan wrong, so every value must come from a source you actually read in this
session.

## Sources, in priority order

1. php.net: release announcements, ChangeLog-8.php, supported-versions.php
2. The php-src GitHub security advisories (GHSA) for the CVEs
3. National CERTs (CISA, NCSC, CERT-EU) for exploitation status
4. Distro trackers for backports: Ubuntu USN, Debian security tracker, Red Hat CVE
   pages, AlmaLinux/Rocky errata, CloudLinux, cPanel EA4 changelog
5. Reputable security press only for context (never as the sole source of a version)

## Steps

1. Search the sources above. Record the URL of each fact.
2. Copy `advisories/php2shell.env` to `advisories/<new-id>.env` (or edit the existing
   one when refreshing) and fill:

| Key | Rule |
|---|---|
| `ADVISORY_ID` | short, dated: `<name>-YYYY-MM` |
| `CVES` | space separated, exactly as assigned |
| `FIXED_VERSIONS` | first fixed upstream release per supported branch, from php.net only |
| `EOL_BELOW` | oldest supported branch per php.net supported-versions page |
| `LEAK_DATE` / `IOC_SINCE` | earliest public detail or exploitation date; `IOC_SINCE` one day earlier |
| `MITIGATION_NOTE` | only what PHP or a CERT states; label anything else as partial |
| `LOG_HEURISTIC_REGEX` | optional; only from a credible technical write-up; empty if unsure |
| `SOURCES`, `LAST_VERIFIED` | URLs used; today's date |

3. Validate the file loads and classifies correctly:
   ```bash
   bash -c '. scripts/lib.sh; load_advisory advisories/<new-id>.env; \
     for v in <one-below-fixed> <fixed> <eol-example>; do classify "$v"; echo "$v $STATUS"; done'
   ```
   Expected: VULNERABLE, PATCHED, EOL.
4. Show the user a diff of the advisory and the sources. Use it with
   `--advisory advisories/<new-id>.env` on every script.

## Never

- Never guess a fixed version from a distro package number or a news article.
- Never mark a mitigation as a fix unless PHP says so.
- Never delete an old advisory file; incident logs reference them.
