# End-of-life branch migration (no patch exists)

Branches older than `EOL_BELOW` in the advisory will not get an official fix. The
only durable answer is moving the site to a supported branch.

## Today: contain

Pick the strongest option the business accepts and log the choice:

1. **Take offline / maintenance mode** for sites that are not needed right now.
2. **Restrict access**: IP allowlist or VPN for admin-only and internal sites.
3. **WAF in front**: CDN/WAF with managed rules and rate limiting. This reduces noise;
   it is not a fix.
4. **Partial hardening** (from the advisory's MITIGATION_NOTE; not a fix):
   `session.upload_progress.enabled = Off`, `session.use_only_cookies = On` in the
   php.ini / pool config for that branch, then reload PHP. Approval required.
5. **Vendor extended support** (distro ESM, CloudLinux alt-php, commercial ELS):
   acceptable only if the vendor publicly confirms a build fixing the advisory CVEs.

## This week: migrate on staging

1. **Inventory** the app: CMS + version, plugins/themes/modules + versions, custom code.
2. **Pick the target**: the newest supported branch the app officially supports.
3. **Clone to staging** (panel staging tool, WP staging plugin, or copy files + DB).
4. **Static compatibility scan**:
   ```bash
   composer global require --dev squizlabs/php_codesniffer phpcompatibility/php-compatibility
   phpcs -p --standard=PHPCompatibility --runtime-set testVersion <target>- --extensions=php <docroot>
   ```
   Treat errors in abandoned plugins as replace/remove decisions, not quick fixes.
5. **Update first, then switch**: CMS core, plugins, themes on the old branch; then
   switch staging to the target branch.
6. **Test**: home, login, checkout/forms, admin, cron jobs, emails, error log clean.
7. **Switch production** using the panel's per-site PHP setting or a new FPM pool;
   keep the old handler available for 48 hours as rollback.
8. **Re-run** `verify.sh` and the fleet scan for that site.

## Talking to clients

Use the `eol-upgrade-proposal` template in pvr-client-comms. Be factual: the risk is
critical, no patch will come for their version, containment buys time but does not
remove the risk.
