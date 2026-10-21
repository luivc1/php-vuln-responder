---
name: pvr-server-audit
description: Audit a server you have shell access to for the current PHP advisory (PHP2Shell and later). Finds every PHP install, the PHP actually serving web traffic, distro backports, hosting panel and the right patch playbook. Use for "check my server", "what PHP is running", "audit this VPS", "revisa mi servidor", "qué PHP tiene mi servidor".
---

# Server Audit (inside, read-only)

Follow **pvr-navigator** rules. Everything in this skill is read-only, so no change
approvals are needed, but confirm the user is authorized on the host.

## Access options

| Situation | How to run |
|---|---|
| Agent has a shell on the host (SSH, device bridge, panel terminal) | Copy `scripts/` to the host (or clone the repo) and run directly |
| Agent has no shell, user does | Give the user the exact commands; ask them to paste output back |
| Container | Run inside the container (`docker compose exec <svc> bash`) and on the host |

Use `sudo` when available for full visibility (it stays read-only).

## Steps

1. **Fingerprint the stack**
   ```bash
   bash "$PVR/scripts/detect-stack.sh" | tee stack-$(hostname).txt
   ```
   Key lines: `PLAYBOOK`, `PANEL`, `FPM_MASTER` (the PHP serving the web),
   `PHP_BIN ... status=`, `LONG_RUNNING_PHP`, `DOCROOT`.
2. **Scan the binaries**
   ```bash
   bash "$PVR/scripts/scan.sh" --local -o reports/local-$(hostname)
   ```
   On Debian/Ubuntu/RHEL family hosts the script reads the installed package's own
   changelog: if it lists every advisory CVE, the binary is reported PATCHED
   ("backport confirmed") even though the version number looks old.
3. **Find the web-facing PHP.** The CLI `php` may differ from what serves sites.
   Trust, in order: `FPM_MASTER` branches, the panel's per-domain PHP setting
   (cPanel MultiPHP Manager, Plesk "PHP settings", CloudLinux Selector), then the
   CLI. If unsure, list it as a gap rather than guessing.
4. **Summarize for the user** (table): branch, where it is used, status, playbook,
   and whether a restart-sensitive process exists (FPM, Apache mod_php, LiteSpeed,
   FrankenPHP, Octane/RoadRunner/queue workers).
5. **Decide next skill**:
   - Any VULNERABLE/EOL/CHECK-unconfirmed -> pvr-patch (run `patch-plan.sh`).
   - Host was exposed on/after `LEAK_DATE` -> pvr-compromise-check. If there are
     visible signs (unknown processes, defaced pages, odd admin users), do the
     compromise check **before** patching and advise isolating the host first.
   - All PATCHED -> pvr-verify-close to confirm processes were restarted.

## Gotchas

- **cPanel/CloudLinux** can have 3 to 6 PHP versions installed at once; each one
  counts if any site uses it, and unused EOL versions should still be removed from
  the selector later.
- **Plesk** binaries live in `/opt/plesk/php/<branch>/`; OS `php` is often unused.
- **Containers**: the host's PHP is irrelevant if sites run in containers; audit the
  image (`docker compose exec <svc> php -v`).
- **macOS/Homebrew** dev machines: low internet exposure, but patch anyway.
