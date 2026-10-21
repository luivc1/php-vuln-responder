#!/usr/bin/env bash
# Shared helpers for php-vuln-responder scripts. Sourced, not executed.
# Needs only bash 3.2+ and coreutils. Nothing in here changes the system.

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ADVISORY="$LIB_DIR/../advisories/php2shell.env"

if [ -t 1 ]; then
  R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; C=$'\033[36m'; D=$'\033[2m'; BD=$'\033[1m'; N=$'\033[0m'
else
  R=; G=; Y=; C=; D=; BD=; N=
fi

load_advisory() { # $1 = path (optional)
  local f="${1:-$DEFAULT_ADVISORY}"
  if [ ! -r "$f" ]; then echo "Advisory file not readable: $f" >&2; exit 3; fi
  # shellcheck disable=SC1090
  . "$f"
  ADVISORY_FILE="$f"
  : "${FIXED_VERSIONS:?advisory is missing FIXED_VERSIONS}" "${EOL_BELOW:?advisory is missing EOL_BELOW}"
}

banner() {
  printf '\n%s%s check%s  %s(%s)%s\n' "$BD$C" "$ADVISORY_NAME" "$N" "$D" "$CVES" "$N"
  printf '%sFixed: %s   Older than %s: EOL, no fix%s\n\n' "$D" "$(echo $FIXED_VERSIONS | sed 's/ / | /g')" "$EOL_BELOW" "$N"
}

ver_ge() { # true if $1 >= $2 (dotted numeric, up to 3 parts)
  local IFS=.
  local a=($1) b=($2) i x y
  for i in 0 1 2; do
    x=${a[$i]:-0}; y=${b[$i]:-0}
    if (( 10#$x > 10#$y )); then return 0; fi
    if (( 10#$x < 10#$y )); then return 1; fi
  done
  return 0
}

fixed_for_branch() { # $1 = "8.3" -> prints "8.3.36" or nothing
  local f
  for f in $FIXED_VERSIONS; do
    case "$f" in "$1".*) echo "$f"; return 0;; esac
  done
  return 1
}

# classify <version string>  ->  sets STATUS and NOTE
#   PATCHED | VULNERABLE | EOL | CHECK
classify() {
  local v="$1" maj min pat base suffix fixed
  if [[ ! $v =~ ^([0-9]+)\.([0-9]+)(\.([0-9]+))? ]]; then
    STATUS="CHECK"; NOTE="Could not parse version '$v'. Verify manually."; return
  fi
  maj=${BASH_REMATCH[1]}; min=${BASH_REMATCH[2]}; pat=${BASH_REMATCH[4]:-0}
  base="$maj.$min.$pat"
  suffix=${v#"${BASH_REMATCH[0]}"}; suffix=${suffix# }
  fixed=$(fixed_for_branch "$maj.$min")

  if [ -z "$fixed" ]; then
    if ver_ge "$maj.$min" "$EOL_BELOW"; then
      STATUS="CHECK"; NOTE="Branch $maj.$min is not listed in advisory $ADVISORY_ID. Confirm on php.net."
    else
      STATUS="EOL"
      NOTE="PHP $maj.$min is end-of-life: no official fix. Move to a supported branch, or isolate the host until upgraded."
      [ -n "$suffix" ] && NOTE="$NOTE Vendor build: $suffix. Ask the vendor whether they shipped a backport."
    fi
    return
  fi

  if ver_ge "$base" "$fixed"; then
    STATUS="PATCHED"; NOTE="At or above the fixed release $fixed."
  elif [ -n "$suffix" ]; then
    STATUS="CHECK"
    NOTE="Upstream $base is below $fixed, but this is a distro/vendor build: $suffix. It may include a backported fix. Check the package changelog for $CVES."
  else
    STATUS="VULNERABLE"; NOTE="Below the fixed release $fixed. Update PHP now."
  fi
}

# Prints every PHP binary (cli, fpm, cgi, lsphp) found in common install
# locations, resolved and de-duplicated, one per line.
discover_php_bins() {
  local b rb out
  out=$(
    for b in $(command -v php php-fpm php-cgi lsphp frankenphp 2>/dev/null) \
             /usr/bin/php[0-9]* /usr/sbin/php-fpm* /usr/local/bin/php /usr/local/sbin/php-fpm \
             /opt/cpanel/ea-php*/root/usr/bin/php /opt/cpanel/ea-php*/root/usr/sbin/php-fpm \
             /opt/alt/php*/usr/bin/php /opt/alt/php*/usr/sbin/php-fpm \
             /opt/remi/php*/root/usr/bin/php /opt/remi/php*/root/usr/sbin/php-fpm \
             /opt/plesk/php/*/bin/php /opt/plesk/php/*/sbin/php-fpm \
             /usr/local/php*/bin/php /usr/local/lsws/lsphp*/bin/lsphp \
             /opt/homebrew/opt/php*/bin/php /usr/local/opt/php*/bin/php; do
      if [ -f "$b" ] && [ -x "$b" ]; then
        rb=$(readlink -f "$b" 2>/dev/null) && b=$rb
        echo "$b"
      fi
    done
  )
  [ -n "$out" ] && printf '%s\n' "$out" | sort -u
}

# php_bin_version <binary> -> prints "8.3.6" (empty if unreadable)
php_bin_version() {
  local b="$1"
  case "$(basename "$b")" in
    frankenphp*) "$b" version </dev/null 2>/dev/null | grep -oE 'PHP [0-9]+\.[0-9]+\.[0-9]+' | head -1 | cut -d' ' -f2 ;;
    *)           "$b" -v </dev/null 2>/dev/null | head -1 | grep -oE 'PHP [0-9]+\.[0-9]+\.[0-9]+[^ ]*' | head -1 | cut -d' ' -f2 ;;
  esac
}

# pkg_lists_cves <pkgname>: true if the installed package's own changelog
# mentions every CVE in the advisory (distro backport confirmed, offline).
pkg_lists_cves() {
  local pkg="$1" log="" cve
  if command -v dpkg >/dev/null 2>&1; then
    for f in /usr/share/doc/"$pkg"/changelog.Debian.gz /usr/share/doc/"$pkg"/changelog.gz; do
      [ -r "$f" ] && { log=$(zcat "$f" 2>/dev/null); break; }
    done
  elif command -v rpm >/dev/null 2>&1; then
    log=$(rpm -q --changelog "$pkg" 2>/dev/null)
  fi
  [ -z "$log" ] && return 1
  for cve in $CVES; do echo "$log" | grep -q "$cve" || return 1; done
  return 0
}

# classify_installed <version> <"pkg ver" or empty>: classify, then upgrade a
# distro CHECK to PATCHED when the package changelog confirms the backport.
classify_installed() {
  local v="$1" pk="$2"
  classify "$v${pk:+ [pkg $pk]}"
  if [ "$STATUS" = CHECK ] && [ -n "$pk" ] && pkg_lists_cves "${pk%% *}"; then
    STATUS="PATCHED"; NOTE="Distro backport confirmed: the ${pk%% *} changelog lists $CVES."
  fi
}

# owning_package <path> -> prints "pkgname version" if a package manager owns it
owning_package() {
  local p="$1" pkg ver
  if command -v dpkg >/dev/null 2>&1; then
    pkg=$(dpkg -S "$p" 2>/dev/null | head -1 | cut -d: -f1)
    [ -n "$pkg" ] && ver=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null)
  elif command -v rpm >/dev/null 2>&1; then
    pkg=$(rpm -qf --qf '%{NAME}' "$p" 2>/dev/null | grep -v 'not owned')
    [ -n "$pkg" ] && ver=$(rpm -q --qf '%{VERSION}-%{RELEASE}' "$pkg" 2>/dev/null)
  fi
  [ -n "$pkg" ] && [ -n "$ver" ] && echo "$pkg $ver"
}
