# Patch playbooks

`<B>` = branch like `8.3`, `<BB>` = `83`, `<FX>` = fixed release for that branch from
the advisory. Commands marked with `sudo` are changes and need approval. Package and
service names below are the common defaults; confirm them on the host
(`systemctl list-units '*php*'`, `dpkg -l '*php*'`, `rpm -qa '*php*'`) before running.

---

## apt (Ubuntu, Debian, including ondrej/sury PPA)

| Step | Command |
|---|---|
| Refresh | `sudo apt-get update` |
| What is offered | `apt-cache policy php<B>-cli php<B>-fpm` |
| Fix included? | Official distro: `apt-get changelog php<B>-cli \| grep -E 'CVE-...'` . ondrej/sury: Candidate upstream version must be >= `<FX>` |
| Upgrade installed php<B> packages only | `dpkg-query -W -f='${binary:Package} ${db:Status-Abbrev}\n' 'php<B>*' \| awk '$2=="ii"{print $1}' \| xargs -r sudo apt-get install --only-upgrade -y` |
| Restart | `sudo systemctl restart php<B>-fpm` and/or `sudo systemctl restart apache2` (mod_php) |
| Rollback | `sudo apt-get install php<B>-cli=<oldversion> php<B>-fpm=<oldversion> ...` (old version from `/var/log/apt/history.log`) |

Notes: Ubuntu ESM/Pro covers some older branches (e.g. php7.x on older LTS) only with
an Ubuntu Pro subscription; confirm the USN lists these CVEs.

## dnf / yum (RHEL, AlmaLinux, Rocky, Oracle, Fedora; AppStream module or Remi module)

| Step | Command |
|---|---|
| What is offered | `sudo dnf check-update 'php*'` |
| Fix included? | Vendor advisory (RHSA/ALSA/RLSA) lists the CVEs; after install: `rpm -q --changelog php-cli \| grep CVE-...` |
| Upgrade | `sudo dnf upgrade 'php*'` |
| Restart | `sudo systemctl restart php-fpm`; `sudo systemctl restart httpd` if mod_php |
| Rollback | `sudo dnf history list php` then `sudo dnf history undo <id>` |

## dnf-remi-scl (Remi parallel installs: /opt/remi/php<BB>)

`sudo dnf upgrade 'php<BB>-*'` then `sudo systemctl restart php<BB>-php-fpm`.
Rollback: `dnf history undo <id>`.

## cpanel-ea (cPanel & WHM EasyApache 4)

- Packages are `ea-php<BB>-*`; cPanel applies updates nightly when "Automatic
  updates" are on. Force now:
  - RHEL family: `sudo dnf upgrade 'ea-php<BB>*'` (yum on CentOS 7)
  - Ubuntu cPanel: `sudo apt-get update` then upgrade the installed `ea-php<BB>*` packages
- Check: `/opt/cpanel/ea-php<BB>/root/usr/bin/php -v`
- Restart: `sudo /scripts/restartsrv_apache_php_fpm` and `sudo /scripts/restartsrv_httpd`
- Move sites off EOL versions in **WHM > MultiPHP Manager**; remove EOL versions in
  **EasyApache 4** once no domain uses them.
- Rollback: `dnf history undo <id>`.

## cloudlinux-alt (CloudLinux alt-php, PHP Selector)

- `sudo yum upgrade 'alt-php<BB>*'` (dnf on newer releases)
- Check: `/opt/alt/php<BB>/usr/bin/php -v`
- Restart the web server: `sudo systemctl restart lsws` (LiteSpeed) or `httpd`
- CloudLinux ships patched alt-php for some EOL branches. Treat them as CHECK until
  their changelog or CloudLinux advisory lists the CVEs.

## plesk

- `sudo plesk installer update` (or **Tools & Settings > Updates** in the UI)
- Check: `/opt/plesk/php/<B>/bin/php -v`
- Restart: `sudo service plesk-php<BB>-fpm restart`
- Per-domain version: **Websites & Domains > PHP**. Move domains off EOL handlers.

## directadmin (CustomBuild compiles from source)

- `cd /usr/local/directadmin/custombuild && sudo ./build update`
- `sudo ./build versions` (shows outdated), then `sudo ./build update_versions`
- Confirm the syntax against the DirectAdmin docs for the installed CustomBuild.
- Rollback: CustomBuild keeps previous builds only if configured; take a snapshot first.

## docker

- Never `apt upgrade` inside a running container; rebuild the image.
- Pin `FROM php:<FX>-fpm` (or `-apache`, `-cli`, `-alpine`) in every Dockerfile,
  then `docker compose build --pull && docker compose up -d`.
- Check: `docker compose exec <svc> php -v`
- Rollback: redeploy the previous image tag (keep it until verify passes).
- Also check third-party images (Bitnami, linuxserver.io, vendor appliances) for
  their own updated tags.

## frankenphp

FrankenPHP embeds PHP. Upgrade the `frankenphp` binary or image to a release built
with PHP >= `<FX>`, check `frankenphp version`, restart the service/container.

## alpine

`sudo apk update && sudo apk upgrade`, check `php<BB> -v`, restart
`php-fpm<BB>` via `rc-service`. Alpine branch repos may lag; check the package version.

## homebrew (macOS dev machines)

`brew update && brew upgrade php` (or `php@<B>`), then `brew services restart php`.

## windows (IIS / XAMPP / Laragon)

Download the fixed build from windows.php.net (or the stack vendor), replace the PHP
folder keeping `php.ini`, restart IIS/Apache. XAMPP/Laragon users wait for the
vendor's bundle or swap the PHP folder manually.

## unknown-or-managed (shared hosting, no root)

1. Hosting panel PHP selector: pick a version at or above `<FX>` if offered.
2. If the selector only lists vulnerable/EOL builds: open a ticket (pvr-client-comms
   `host-ticket`) asking for the build and confirmation that the CVEs are fixed.
3. Containment meanwhile: put the site behind a WAF/CDN rule set and enable
   maintenance mode for high-risk sites if the host gives no ETA.

---

## Long-running PHP (any playbook)

Restart after the interpreter upgrade or they keep running the old one:
Laravel Octane (`php artisan octane:reload`), Horizon/queue workers
(`php artisan horizon:terminate` / supervisor restart), RoadRunner (`rr reset`),
Swoole servers, cron daemons written in PHP. `verify.sh` flags any process still
using a replaced binary.
