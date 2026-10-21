#!/usr/bin/env bash
# =====================================================================
#  detect-stack.sh  -  fingerprint a server so the agent picks the right
#  patch playbook. READ-ONLY: it lists files, processes and versions.
#
#  Usage:  detect-stack.sh [--advisory file]
#  Output: KEY=value lines (easy for agents and for patch-plan.sh)
# =====================================================================

. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ADV=""; [ "$1" = "--advisory" ] && ADV="$2"
load_advisory "$ADV" >/dev/null

kv() { printf '%s=%s\n' "$1" "$2"; }
has() { command -v "$1" >/dev/null 2>&1; }
norm_branch() { # "php/8.3" "ea-php83" "php83" -> 8.3
  local d; d=$(echo "$1" | grep -oE '[0-9]+\.?[0-9]+' | head -1)
  case "$d" in *.*) echo "$d";; ??) echo "${d:0:1}.${d:1}";; *) echo "$d";; esac
}

echo "# detect-stack $(date -u '+%Y-%m-%dT%H:%M:%SZ') advisory=$ADVISORY_ID"

# ---- OS / platform ----------------------------------------------------
if [ -r /etc/os-release ]; then . /etc/os-release; kv OS "${PRETTY_NAME:-$ID}"; kv OS_ID "${ID:-unknown}"; kv OS_VERSION "${VERSION_ID:-}";
elif [ "$(uname -s)" = "Darwin" ]; then kv OS "macOS $(sw_vers -productVersion 2>/dev/null)"; kv OS_ID macos
else kv OS "$(uname -s)"; kv OS_ID "$(uname -s | tr 'A-Z' 'a-z')"; fi
kv HOSTNAME "$(hostname 2>/dev/null || uname -n)"
kv IS_ROOT "$([ "$(id -u)" = 0 ] && echo yes || echo no)"
kv HAS_SUDO "$(has sudo && echo yes || echo no)"
if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then kv CONTAINER yes; else kv CONTAINER no; fi

PM=none
for p in apt-get dnf yum apk zypper brew; do has "$p" && { PM=$p; break; }; done
kv PKG_MANAGER "$PM"

# ---- hosting panel ------------------------------------------------------
PANEL=none
[ -f /usr/local/cpanel/version ]   && PANEL="cpanel $(cat /usr/local/cpanel/version 2>/dev/null)"
[ -f /usr/local/psa/version ]      && PANEL="plesk $(head -1 /usr/local/psa/version 2>/dev/null | cut -d' ' -f1)"
[ -d /usr/local/directadmin ]      && PANEL="directadmin"
[ -d /usr/local/CyberCP ]          && PANEL="cyberpanel"
[ -d /usr/local/hestia ]           && PANEL="hestiacp"
[ -d /RunCloud ] || [ -d /etc/runcloud ] && PANEL="runcloud"
kv PANEL "$PANEL"
CL=no; { [ -f /etc/cloudlinux-release ] || uname -r | grep -q lve; } && CL=yes
kv CLOUDLINUX "$CL"

# ---- package repos for PHP ---------------------------------------------
REPO=distro
if [ -d /etc/apt ] && grep -rqsE 'ondrej/php|packages\.sury\.org/php' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then REPO=ondrej-sury; fi
if [ -d /etc/yum.repos.d ] && ls /etc/yum.repos.d 2>/dev/null | grep -qi remi; then REPO=remi; fi
kv PHP_REPO "$REPO"

# ---- web servers & PHP handlers -----------------------------------------
PS=$(ps -eo pid=,args= 2>/dev/null)
WS=""
for w in nginx apache2 httpd lshttpd litespeed caddy frankenphp openlitespeed; do
  echo "$PS" | grep -E "[/ ]$w( |:|$)" | grep -vq grep && WS="$WS $w"
done
kv WEB_SERVERS "$(echo $WS)"

MODPHP=no
if ls /etc/apache2/mods-enabled/php*.load >/dev/null 2>&1 || ls /etc/httpd/conf.modules.d/*php* >/dev/null 2>&1; then MODPHP=yes; fi
kv APACHE_MOD_PHP "$MODPHP"

# Running FPM masters = the PHP actually serving web traffic
echo "$PS" | grep 'php-fpm: master process' | grep -v grep | while read -r pid rest; do
  conf=$(echo "$rest" | grep -oE '\(.*\)' | tr -d '()')
  br=$(norm_branch "$conf")
  start=$(ps -o lstart= -p "$pid" 2>/dev/null | sed 's/  */ /g')
  kv FPM_MASTER "pid=$pid branch=$br config=$conf started=\"$start\""
done

LONG=$(echo "$PS" | grep -E 'frankenphp|rr serve|octane|swoole|artisan (queue|horizon)|php-pm' | grep -v grep | awk '{$1=""; print substr($0,2)}' | cut -c1-120)
if [ -n "$LONG" ]; then echo "$LONG" | while IFS= read -r l; do kv LONG_RUNNING_PHP "$l"; done; fi

# ---- every PHP binary ---------------------------------------------------
bins=$(discover_php_bins)
if [ -n "$bins" ]; then
  while IFS= read -r b; do
    v=$(php_bin_version "$b"); pk=$(owning_package "$b")
    classify_installed "${v:-?}" "$pk"
    kv PHP_BIN "path=$b version=${v:-?} package=\"${pk:-none}\" status=$STATUS"
  done <<< "$bins"
else
  kv PHP_BIN "none-found"
fi

# ---- docroots (for ioc-hunt) -------------------------------------------
for d in /var/www /home/*/public_html /home/*/domains/*/public_html /var/www/vhosts/*/httpdocs /usr/share/nginx/html /srv/www /opt/bitnami/apps; do
  [ -d "$d" ] && kv DOCROOT "$d"
done

# ---- recommended playbook ---------------------------------------------
PB=unknown-or-managed
if   [ "$(echo "$PS" | grep -c '[f]rankenphp')" -gt 0 ]; then PB=frankenphp
elif [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then PB=docker
else
  case "$PANEL" in
    cpanel*)      PB=cpanel-ea;;
    plesk*)       PB=plesk;;
    directadmin)  PB=directadmin;;
    *)
      if   [ "$CL" = yes ] && ls -d /opt/alt/php* >/dev/null 2>&1; then PB=cloudlinux-alt
      elif [ "$PM" = apt-get ]; then PB=apt
      elif [ "$PM" = dnf ] || [ "$PM" = yum ]; then
        if ls -d /opt/remi/php* >/dev/null 2>&1; then PB=dnf-remi-scl; else PB=dnf; fi
      elif [ "$PM" = apk ]; then PB=alpine
      elif [ "$PM" = brew ]; then PB=homebrew
      fi;;
  esac
fi
kv PLAYBOOK "$PB"
echo "# next: patch-plan.sh prints the commands for PLAYBOOK=$PB (it does not run them)"
