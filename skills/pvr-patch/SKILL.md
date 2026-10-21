---
name: pvr-patch
description: Patch PHP on a server for the current advisory (PHP2Shell and later) with approval gates, backups, restarts and rollback. Covers apt, dnf, Remi, cPanel EA4, CloudLinux alt-php, Plesk, DirectAdmin, Docker, FrankenPHP, Homebrew, managed hosting, and end-of-life branch migrations. Use for "patch PHP", "update PHP", "fix the vulnerability", "parchar PHP", "actualizar PHP", "aplicar el parche".
---

# Patch (changes the system: approval required at every step)

Follow **pvr-navigator** rules, especially rule 3: show the exact command, impact,
downtime and rollback, then wait for an explicit yes for **each** command.

## 1. Plan (read-only)

```bash
bash "$PVR/scripts/patch-plan.sh" | tee plan-$(hostname).txt
```
It runs detect-stack and prints the commands for the detected playbook, with the
branches that need action. It never executes them. Use `--playbook <name>` to
override, or `--stack stack.txt` to reuse a saved audit.

Read `references/playbooks.md` for the matching playbook's details and rollback
before proposing anything.

## 2. Pre-flight checklist (present it, get one approval for the whole list)

- [ ] Snapshot or backup taken (provider snapshot preferred; else configs + DB dump)
- [ ] Compromise signs checked (if obvious signs: isolate and run
      pvr-compromise-check first; patching an infected host loses evidence context)
- [ ] Maintenance window agreed (restarts are seconds per pool; stores may prefer
      off-peak, but a critical RCE under active exploitation justifies doing it now)
- [ ] Rollback command written down (from playbooks.md)

## 3. Execute, one step at a time

For each command in the plan:
1. Show it in a code block with a one-line "what this does".
2. Wait for "yes" (or the user's equivalent in Spanish: "sí", "dale", "adelante").
3. Run it, show the relevant output lines, log it in `pvr-log.md`.
4. If anything unexpected appears (dependency removals, held packages, config file
   prompts, a different version than planned), **stop** and ask. Never answer
   package-manager prompts with blanket "yes" or force flags.

Order inside a branch: refresh index -> confirm the fixed build is offered ->
upgrade -> restart PHP services -> restart long-running workers.

## 4. When the fix is not available yet

- Distro has not published the backport: say so, show how to check again
  (`apt-cache policy` / `dnf check-update`), and apply containment from the
  advisory's `MITIGATION_NOTE` meanwhile. Re-check every few hours.
- Panel/host lags (cPanel EA4, CloudLinux, Plesk): same, plus the host-ticket
  template in pvr-client-comms for managed servers.

## 5. End-of-life branches

There is no patch for EOL branches. Follow `references/eol-migration.md`: contain
today, migrate on staging, switch, keep a rollback handler. Never jump a production
site across major branches in place without a staging test, even if the user is in
a hurry; offer containment instead to buy time.

## 6. Hand off

Always finish with **pvr-verify-close**. A patch is not done until verify passes
(no vulnerable binaries, no stale processes) and the incident log is updated.
