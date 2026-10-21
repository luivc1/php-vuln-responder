---
name: pvr-client-comms
description: Bilingual (English/Spanish) messages for a PHP vulnerability incident (PHP2Shell and later) - client advisory, hosting-provider ticket, patched confirmation, end-of-life upgrade proposal, compromise notice. Use for "tell my clients", "email the host", "write the update", "avísale a mis clientes", "escribe al hosting", "redacta el correo".
---

# Client and Host Communications

Follow **pvr-navigator** rules: facts come from the advisory file, the scan/verify
reports and `pvr-log.md`. Never claim a site is safe without a PASS from verify, and
never claim it was not compromised; say what was checked.

## Pick the template (in `templates/`)

| Situation | Template |
|---|---|
| First notice to clients: we know, we are checking | `client-advisory.md` |
| Managed/shared hosting, need the host to act or confirm | `host-ticket.md` |
| Patched and verified | `patched-confirmation.md` |
| Client is on an EOL branch, needs a migration | `eol-upgrade-proposal.md` |
| Compromise confirmed or strongly suspected | `compromise-notice.md` |

## How to fill

1. Use the client's language (EN or ES; Puerto Rico clients often prefer Spanish,
   ask if unsure). Each template has both versions.
2. Replace every `{{placeholder}}` from real data. If a value is unknown, ask or
   remove the sentence; never leave a placeholder or guess a version.
3. Keep it short and calm: what happened, what it means for them, what we did, what
   they need to do (often nothing), when they will hear next.
4. Do not include exploit details, internal hostnames, IPs, or secrets.
5. Attach the client-facing HTML report only for their own sites.
6. Draft only. Sending email or posting is an action the user approves (and, with an
   email connector, a draft in their mail client is the right default).
