# Cleanup and credential rotation (every step needs approval)

Do these only after evidence is copied aside and PHP is patched.

## Remove footholds

| Foothold | Action |
|---|---|
| PHP in uploads/media | Move to evidence folder (do not delete): `sudo mv <file> /root/evidence-<date>/quarantine/` |
| Modified core/plugin files | Reinstall from a clean source: `wp core download --force --skip-content --version=<same>`, `wp plugin install <slug> --force --version=<same>`; for other apps redeploy from git/vendor zip |
| Unknown cron/systemd/SSH keys | Remove the entry after copying it to evidence |
| Unknown admin users | Demote/remove after export (`wp user list` output to evidence) |
| Running shells/miners | `kill` after recording `ps` output and `/proc/<pid>/exe` path |
| `.htaccess` / `.user.ini` injections | Restore from backup or remove injected lines (auto_prepend_file is a classic) |

Prefer **rebuild from known-good backup** (taken before `LEAK_DATE`) plus patched PHP
when there are many footholds.

## Block uploads from executing PHP (hardening, approval)

- Nginx: `location ~* /(?:uploads|files)/.*\.php$ { deny all; }`
- Apache (`uploads/.htaccess`): `<FilesMatch "\.(php|phtml|phar)$">Require all denied</FilesMatch>`

## Rotate credentials (the PHP user could read all of these)

- Database passwords in `wp-config.php` / `.env` / `config.php` (update the app config after)
- WordPress salts and keys (`wp config shuffle-salts`)
- All admin/editor passwords; force logout of sessions
- API keys stored in config or DB: payment gateways (Stripe etc.), SMTP, cloud
  storage, CRM, analytics with write access
- SSH keys and panel passwords if the web user could reach them
- Hosting/panel accounts if any shell ran as a privileged user

## Afterwards

- Re-run `ioc-hunt.sh --deep` and `verify.sh`.
- Watch logs for 7 days for reinfection (same file paths reappearing is a sign the
  entry point or a foothold was missed).
