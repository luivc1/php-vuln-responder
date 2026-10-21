---
name: pvr-verify-close
description: Prove a PHP patch took effect and close the incident: no vulnerable binaries, no PHP process still running the old interpreter, public re-scan, closure report. Use after patching or for "did the patch work", "verify the fix", "close the incident", "verificar el parche", "confirmar que quedó arreglado".
---

# Verify and Close

Follow **pvr-navigator** rules. Verification is read-only.

For high-stakes fleets (stores, many clients), have a separate agent or a person who
did not run the patch do this verification, so the work is not grading itself. In
Claude Code the bundled `pvr-verifier` subagent exists for this.

## 1. Verify each host

```bash
bash "$PVR/scripts/verify.sh" --url https://<site1> --url https://<site2>
```

| Result | Meaning | Action |
|---|---|---|
| PASS | No vulnerable binaries, no stale processes | Continue to closure |
| CONFIRM | Distro/vendor builds not yet confirmed to carry the backport | Check the vendor advisory or `apt-get changelog`/`rpm -q --changelog`; if the CVEs are not listed, the patch is not in: back to pvr-patch |
| FAIL (STALE) | A PHP process still runs the replaced binary | Restart that service (approval), re-run verify |
| FAIL (VULNERABLE/EOL) | A binary is still exposed | Back to pvr-patch |

Remember the CLI is not the web PHP: the stale-process check and panel settings are
what prove the web side is fixed.

## 2. Re-scan the fleet

Re-run the pvr-fleet-scan command on the full list and attach the new HTML report.
Every site should be PATCHED or HIDDEN-with-host-confirmation.

## 3. Closure checklist

- [ ] Every host: verify PASS
- [ ] Every exposed host: compromise check done (result recorded, gaps listed)
- [ ] EOL sites: migrated, or containment recorded with a migration date
- [ ] Temporary hardening changes recorded (so they can be reviewed later)
- [ ] Credentials rotated where compromise was confirmed
- [ ] Scheduled re-scans stopped, or kept 7 days after the last fix
- [ ] Incident log `pvr-log.md` complete

## 4. Closure summary

Write a short summary for the user (and for clients via pvr-client-comms):
scope, what was found, what was changed and when, what is still open with owners
and dates, and the evidence (reports, log). Keep secrets out of it.
