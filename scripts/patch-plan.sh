#!/usr/bin/env bash
# =====================================================================
#  patch-plan.sh  -  print a step-by-step patch plan for THIS server.
#  DRY RUN ONLY: it never executes the commands it prints. The agent (or
#  you) runs them one step at a time, with human approval.
#
#  Usage:
#    patch-plan.sh                       # detect stack, then plan
#    patch-plan.sh --playbook apt        # force a playbook
#    patch-plan.sh --stack stack.txt     # reuse saved detect-stack output
#    patch-plan.sh --advisory file.env
#
#  Playbooks: apt dnf dnf-remi-scl cpanel-ea cloudlinux-alt plesk
#             directadmin docker frankenphp alpine homebrew unknown-or-managed
# =====================================================================

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"

ADV=""; PB=""; STACKF=""
while [ $# -gt 0 ]; do
  case "$1" in
    --advisory) ADV="$2"; shift 2;;
    --playbook) PB="$2"; shift 2;;
    --stack)    STACKF="$2"; shift 2;;
    -h|--help)  sed -n '2,16p' "$0" | sed 's/^#//'; exit 0;;
    *) echo "Unknown option: $1"; exit 3;;
  esac
done
load_advisory "$ADV"

if [ -n "$STACKF" ]; then STACK=$(cat "$STACKF"); else STACK=$(bash "$HERE/detect-stack.sh" ${ADV:+--advisory "$ADV"}); fi
get() { echo "$STACK" | grep "^$1=" | head -1 | cut -d= -f2-; }
[ -z "$PB" ] && PB=$(get PLAYBOOK)
MODPHP=$(get APACHE_MOD_PHP); WS=$(get WEB_SERVERS); OSID=$(get OS_ID)
CVE_RE=$(echo $CVES | sed 's/ /|/g')

# Branches present and their worst status
BR_LINES=$(echo "$STACK" | grep '^PHP_BIN=' | sed -E 's/.*version=([0-9]+\.[0-9]+)[^ ]* .*status=([A-Z-]+).*/\1 \2/' | grep -E '^[0-9]' | sort -u)
FPM_BR=$(echo "$STACK" | grep '^FPM_MASTER=' | grep -oE 'branch=[0-9.]+' | cut -d= -f2 | sort -u)
ACT_BR=$(echo "$BR_LINES" | awk '$2=="VULNERABLE"||$2=="CHECK"{print $1}' | sort -u)
EOL_BR=$(echo "$BR_LINES" | awk '$2=="EOL"{print $1}' | sort -u)
OK_BR=$(echo "$BR_LINES"  | awk '$2=="PATCHED"{print $1}' | sort -u)

step() { printf '\n%s%s%s\n' "$BD$C" "$1" "$N"; }
cmd()  { printf '  %s$%s %s\n' "$D" "$N" "$1"; }
say()  { printf '  %s\n' "$1"; }

printf '\n%s%s PATCH PLAN (dry run, nothing is executed)%s\n' "$BD" "$ADVISORY_NAME" "$N"
say "Host: $(get HOSTNAME)   OS: $(get OS)   Panel: $(get PANEL)   Playbook: $PB"
say "Web servers: ${WS:-none seen}   mod_php: ${MODPHP:-?}   FPM branches running: $(echo $FPM_BR)"
say "Branches to patch: ${ACT_BR:-none}   EOL branches: ${EOL_BR:-none}   Already patched: ${OK_BR:-none}"

if [ -z "$ACT_BR" ] && [ -z "$EOL_BR" ]; then
  printf '\n%sNothing to patch on this host.%s Still run verify.sh to confirm the running processes, and ioc-hunt.sh if the host was exposed after %s.\n\n' "$G" "$N" "$LEAK_DATE"
  exit 0
fi

step "STEP 0  Safety first (needs approval)"
say "- Take a provider snapshot or backup (VM snapshot, or at minimum /etc/php*, web configs, and a DB dump)."
say "- Pick the window: an FPM/web restart is a few seconds of downtime per pool."
say "- If this host may already be compromised, run ioc-hunt.sh BEFORE patching: patching does not remove backdoors."
say "- Agents: get explicit human approval before every command marked with sudo."

for B in $ACT_BR; do
  BB=$(echo "$B" | tr -d .); FX=$(fixed_for_branch "$B")
  step "STEP 1-3  PHP $B  ->  needs $FX or a vendor build with the backport"
  case "$PB" in
    apt)
      say "1. Refresh and see what the repo offers:"
      cmd "sudo apt-get update"
      cmd "apt-cache policy php$B-cli php$B-fpm | grep -E 'Installed|Candidate'"
      say "   Confirm the fix is in the candidate (official Ubuntu/Debian changelogs list CVEs; for ondrej/sury compare Candidate >= $FX):"
      cmd "apt-get changelog php$B-cli 2>/dev/null | grep -m5 -E '$CVE_RE'"
      say "2. Upgrade only the installed php$B packages:"
      cmd "dpkg-query -W -f='\${binary:Package} \${db:Status-Abbrev}\\n' 'php$B*' | awk '\$2==\"ii\"{print \$1}' | xargs -r sudo apt-get install --only-upgrade -y"
      say "3. Restart what serves PHP:"
      if echo " $(echo $FPM_BR) " | grep -q " $B "; then cmd "sudo systemctl restart php$B-fpm"
      else cmd "sudo systemctl restart php$B-fpm   # only if php$B-fpm is installed (no running master seen)"; fi
      [ "$MODPHP" = yes ] && cmd "sudo systemctl restart apache2";;
    dnf)
      say "1. See what the repo offers and confirm the fix:"
      cmd "sudo dnf check-update 'php*'"
      cmd "rpm -q --changelog php-cli | grep -m5 -E '$CVE_RE'   # after upgrade, or check your vendor advisory (RHSA/ALSA)"
      say "2. Upgrade:"
      cmd "sudo dnf upgrade 'php*'"
      say "3. Restart:"
      cmd "sudo systemctl restart php-fpm"
      [ "$MODPHP" = yes ] && cmd "sudo systemctl restart httpd";;
    dnf-remi-scl)
      cmd "sudo dnf check-update 'php$BB-*'"
      cmd "sudo dnf upgrade 'php$BB-*'"
      cmd "sudo systemctl restart php$BB-php-fpm";;
    cpanel-ea)
      say "cPanel EA4 packages (ea-php$BB). cPanel updates these nightly when auto-updates are on; force it now:"
      if [ "$OSID" = ubuntu ]; then
        cmd "sudo apt-get update && dpkg-query -W -f='\${binary:Package}\\n' 'ea-php$BB*' | xargs -r sudo apt-get install --only-upgrade -y"
      else
        cmd "sudo dnf upgrade 'ea-php$BB*'    # use yum on CentOS 7"
      fi
      cmd "/opt/cpanel/ea-php$BB/root/usr/bin/php -v"
      cmd "sudo /scripts/restartsrv_apache_php_fpm && sudo /scripts/restartsrv_httpd";;
    cloudlinux-alt)
      say "CloudLinux alt-php (used by the PHP Selector):"
      cmd "sudo yum upgrade 'alt-php$BB*'   # dnf on newer CloudLinux"
      cmd "/opt/alt/php$BB/usr/bin/php -v"
      cmd "sudo systemctl restart lsws 2>/dev/null || sudo systemctl restart httpd";;
    plesk)
      cmd "sudo plesk installer update    # or Tools & Settings > Updates in the UI"
      cmd "/opt/plesk/php/$B/bin/php -v"
      cmd "sudo service plesk-php$BB-fpm restart";;
    directadmin)
      say "CustomBuild compiles PHP from source (confirm syntax against DirectAdmin docs for your version):"
      cmd "cd /usr/local/directadmin/custombuild && sudo ./build update"
      cmd "sudo ./build versions          # lists outdated components"
      cmd "sudo ./build update_versions   # rebuilds outdated ones, including PHP";;
    docker)
      say "Containers are patched by rebuilding, not by apt inside the container:"
      cmd "grep -rn '^FROM .*php' --include=Dockerfile* ."
      say "Pin the base image to the fixed release, e.g. FROM php:$FX-fpm (or -apache/-cli), then:"
      cmd "docker compose build --pull && docker compose up -d"
      cmd "docker compose exec <service> php -v";;
    frankenphp)
      say "FrankenPHP embeds PHP: upgrade the frankenphp binary or image to a build that ships PHP >= $FX."
      cmd "frankenphp version"
      say "Then restart the frankenphp service/container.";;
    alpine)
      cmd "sudo apk update && sudo apk upgrade"
      cmd "php$BB -v 2>/dev/null || php -v"
      cmd "sudo rc-service php-fpm$BB restart 2>/dev/null || sudo rc-service php-fpm restart";;
    homebrew)
      cmd "brew update && brew upgrade php php@$B 2>/dev/null"
      cmd "brew services restart php 2>/dev/null; brew services restart php@$B 2>/dev/null";;
    *)
      say "No root package manager or panel detected (likely shared/managed hosting)."
      say "- Check the hosting panel's PHP selector / MultiPHP and pick a fixed release if offered."
      say "- Otherwise open a ticket with the host (client-comms skill has a host-ticket template)."
      say "- Ask the host to confirm the exact PHP build serving the site and whether $CVES is fixed.";;
  esac
done

if echo "$STACK" | grep -q '^LONG_RUNNING_PHP='; then
  step "Long-running PHP workers detected (must restart or they keep the old interpreter)"
  echo "$STACK" | grep '^LONG_RUNNING_PHP=' | cut -d= -f2- | sed 's/^/  - /'
  say "Restart them via their supervisor (e.g. sudo supervisorctl restart all, php artisan octane:reload, systemctl restart <unit>)."
fi

for B in $EOL_BR; do
  step "EOL BRANCH  PHP $B  (no official fix exists)"
  say "Do NOT jump branches in place on production. Plan:"
  say "1. Interim containment today: restrict exposure (WAF rule, IP allowlist, VPN, or take offline)."
  say "   Partial hardening only: session.upload_progress.enabled = Off, session.use_only_cookies = On."
  say "2. Clone the site to staging and pick the newest branch the app officially supports ($(echo $FIXED_VERSIONS | tr ' ' '\n' | cut -d. -f1-2 | tr '\n' ' '))."
  say "3. Compatibility check before switching:"
  cmd "composer global require --dev squizlabs/php_codesniffer phpcompatibility/php-compatibility"
  cmd "phpcs -p --standard=PHPCompatibility --runtime-set testVersion 8.2- --extensions=php <docroot>"
  say "   WordPress: update core, plugins and themes first (wp core update; wp plugin update --all on staging)."
  say "4. Install the new branch side by side and switch the site's handler (MultiPHP / Plesk handler / new FPM pool)."
  say "5. Test staging, switch production, keep the old handler available for quick rollback for 48h."
  say "6. Vendor extended support (distro ESM or commercial ELS) is an option only if they confirm a fix for $CVES."
done

step "STEP 4  Verify"
cmd "bash $(basename "$HERE")/verify.sh --url https://<site>"
say "verify.sh re-scans, checks that every FPM master restarted after the upgrade, and flags stale workers."
step "STEP 5  Compromise check (if exposed after $LEAK_DATE)"
cmd "bash $(basename "$HERE")/ioc-hunt.sh --since $IOC_SINCE"
echo
