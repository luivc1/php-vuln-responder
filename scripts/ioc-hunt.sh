#!/usr/bin/env bash
# =====================================================================
#  ioc-hunt.sh  -  compromise triage for web hosts exposed to a PHP RCE.
#
#  READ-ONLY. It lists, reads and greps. It never deletes, quarantines,
#  edits, or executes site code. Every finding is a LEAD to review, not
#  proof: plugin updates and deploys also change files.
#  Run with sudo for full coverage (other users' crontabs, logs).
#
#  Usage:
#    ioc-hunt.sh                          # auto-detect docroots and logs
#    ioc-hunt.sh --since 2026-10-19 --root /var/www/site --logs /var/log/nginx
#    ioc-hunt.sh --deep                   # pattern-grep ALL php files (slower)
#    ioc-hunt.sh --wp                     # also list WordPress admins via wp-cli
#                                         # (plugins/themes skipped, so site code
#                                         #  is not loaded)
#    ioc-hunt.sh -o report.txt  --max 40
#
#  Exit codes: 0 no leads, 1 leads found (review them), 3 usage error
# =====================================================================

. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

ADV=""; SINCE=""; ROOTS=(); LOGS=(); DEEP=0; WP=0; MAX=25; OUTF=""
while [ $# -gt 0 ]; do
  case "$1" in
    --advisory) ADV="$2"; shift 2;;
    --since)    SINCE="$2"; shift 2;;
    --root)     ROOTS+=("$2"); shift 2;;
    --logs)     LOGS+=("$2"); shift 2;;
    --deep)     DEEP=1; shift;;
    --wp)       WP=1; shift;;
    --max)      MAX="$2"; shift 2;;
    -o|--out)   OUTF="$2"; shift 2;;
    -h|--help)  sed -n '2,22p' "$0" | sed 's/^#//'; exit 0;;
    *) echo "Unknown option: $1"; exit 3;;
  esac
done
load_advisory "$ADV"
SINCE="${SINCE:-$IOC_SINCE}"
HOST=$(hostname 2>/dev/null || uname -n)
OUTF="${OUTF:-ioc-report-$HOST-$(date +%Y%m%d-%H%M).txt}"
TMP=$(mktemp -d 2>/dev/null || mktemp -d -t pvr); trap 'rm -rf "$TMP"' EXIT
LEADS=0

if [ ${#ROOTS[@]} -eq 0 ]; then
  for d in /var/www /home/*/public_html /home/*/domains/*/public_html /var/www/vhosts/*/httpdocs /usr/share/nginx/html /srv/www /opt/bitnami/apps; do
    [ -d "$d" ] && ROOTS+=("$d")
  done
fi
if [ ${#LOGS[@]} -eq 0 ]; then
  for d in /var/log/nginx /var/log/apache2 /var/log/httpd /usr/local/apache/domlogs /var/www/vhosts/system/*/logs /usr/local/lsws/logs /var/log/caddy; do
    [ -d "$d" ] && LOGS+=("$d")
  done
fi

exec > >(tee "$OUTF") 2>&1

section() { printf '\n%s== %s ==%s\n' "$BD$C" "$1" "$N"; }
show() { # $1 = file with findings, $2 = label
  local n; n=$(grep -c . "$1" 2>/dev/null); n=${n:-0}
  if [ "$n" -gt 0 ]; then
    LEADS=$((LEADS+n))
    printf '%s%d lead(s)%s %s\n' "$Y$BD" "$n" "$N" "$2"
    head -n "$MAX" "$1" | sed 's/^/   /'
    [ "$n" -gt "$MAX" ] && printf '   %s... %d more (raise --max)%s\n' "$D" "$((n-MAX))" "$N"
  else
    printf '%sclean%s  %s\n' "$G" "$N" "$2"
  fi
}

printf '%s%s compromise triage%s  host=%s  since=%s  advisory=%s\n' "$BD" "$ADVISORY_NAME" "$N" "$HOST" "$SINCE" "$ADVISORY_ID"
printf 'Docroots: %s\nLogs: %s\n' "${ROOTS[*]:-none found (use --root)}" "${LOGS[*]:-none found (use --logs)}"
[ "$(id -u)" != 0 ] && printf '%sNot running as root: some areas may be unreadable.%s\n' "$Y" "$N"

PHPX='\( -name "*.php" -o -name "*.phtml" -o -name "*.php[0-9]" -o -name "*.phar" -o -name "*.inc" \)'

# 1. Recently modified PHP and server-config files ----------------------
section "1. PHP / .htaccess / .user.ini files modified since $SINCE"
: > "$TMP/recent"
for r in "${ROOTS[@]}"; do
  eval "find \"\$r\" -xdev -type f $PHPX -newermt \"\$SINCE\" -not -path '*/cache/*' 2>/dev/null" >> "$TMP/recent"
  find "$r" -xdev -type f \( -name '.htaccess' -o -name '.user.ini' -o -name 'php.ini' \) -newermt "$SINCE" 2>/dev/null >> "$TMP/recent"
done
show "$TMP/recent" "recently modified files (expected after updates/deploys; review unfamiliar ones)"

# 2. Executable PHP inside upload / media folders -------------------------
section "2. PHP files inside upload/media folders (any date)"
: > "$TMP/uploads"
for r in "${ROOTS[@]}"; do
  # match on the path RELATIVE to the docroot, so a docroot that itself sits
  # under /tmp or /files does not make every file a hit
  eval "find \"\$r\" -xdev -type f $PHPX 2>/dev/null" | while IFS= read -r f; do
    rel="${f#"$r"}"
    echo "$rel" | grep -qE '/(uploads|upload|images|media|files|tmp)/' || continue
    echo "$rel" | grep -qE '/uploads/index\.php$' && continue
    echo "$f"
  done >> "$TMP/uploads"
done
show "$TMP/uploads" "PHP where only images/documents should live"

# 3. Web-shell code patterns -------------------------------------------------
section "3. Web-shell style code patterns"
PAT='eval[[:space:]]*\([[:space:]]*(base64_decode|gzinflate|gzuncompress|str_rot13|\$_(POST|GET|REQUEST|COOKIE))|assert[[:space:]]*\([[:space:]]*\$_(POST|GET|REQUEST|COOKIE)|(system|passthru|shell_exec|popen|proc_open)[[:space:]]*\([[:space:]]*\$_(POST|GET|REQUEST|COOKIE|SERVER)|\$_(POST|GET|REQUEST|COOKIE)[[:space:]]*\[[^]]{1,40}\][[:space:]]*\(|preg_replace[[:space:]]*\([[:space:]]*["'"'"'][^"'"'"']*/e["'"'"']|base64_decode[[:space:]]*\([[:space:]]*["'"'"'][A-Za-z0-9+/=]{300,}'
: > "$TMP/pat"
if [ "$DEEP" -eq 1 ]; then
  for r in "${ROOTS[@]}"; do
    grep -rlE --include='*.php' --include='*.phtml' --include='*.inc' "$PAT" "$r" 2>/dev/null >> "$TMP/pat"
  done
  scope="all PHP files (--deep)"
else
  sort -u "$TMP/recent" "$TMP/uploads" | grep -E '\.(php[0-9]?|phtml|inc|phar)$' | while IFS= read -r f; do
    grep -lE "$PAT" "$f" 2>/dev/null
  done >> "$TMP/pat"
  scope="files from sections 1-2 (use --deep for everything)"
fi
show "$TMP/pat" "files matching eval/exec-on-request-input patterns; scope: $scope"

# 4. Persistence: cron, systemd, SSH keys -----------------------------------
section "4. Persistence changed since $SINCE (cron, systemd, SSH keys)"
: > "$TMP/persist"
find /etc/cron* /var/spool/cron /var/spool/cron/crontabs /etc/systemd/system -type f -newermt "$SINCE" 2>/dev/null >> "$TMP/persist"
find /root/.ssh /home/*/.ssh /var/www/.ssh -name 'authorized_keys*' -newermt "$SINCE" 2>/dev/null >> "$TMP/persist"
for u in www-data apache nginx nobody http lsadm; do
  id "$u" >/dev/null 2>&1 && crontab -l -u "$u" 2>/dev/null | grep -v '^#' | grep . | sed "s|^|crontab($u): |" >> "$TMP/persist"
done
show "$TMP/persist" "new/changed scheduled jobs, services, keys (web-user crontabs should usually be empty)"

# 5. Suspicious processes run by web users ----------------------------------
section "5. Shells / downloaders running as web users"
: > "$TMP/proc"
for u in www-data apache nginx nobody http lsadm; do
  id "$u" >/dev/null 2>&1 || continue
  ps -u "$u" -o user=,pid=,etime=,args= 2>/dev/null | grep -E '(^|[ /])(sh|bash|dash|nc|ncat|socat|curl|wget|perl|python[0-9.]*|base64|xmrig|kdevtmpfsi)( |$)' >> "$TMP/proc"
done
show "$TMP/proc" "web-server users should not be running shells, miners or downloaders"

# 6. Outbound connections from interpreters ---------------------------------
section "6. Established connections owned by php/perl/python/shells"
: > "$TMP/net"
if command -v ss >/dev/null 2>&1; then
  ss -tnpH state established 2>/dev/null | grep -E '"(php[^"]*|perl|python[^"]*|sh|bash|nc|socat)"' >> "$TMP/net"
fi
show "$TMP/net" "PHP-FPM talking to your DB/cache is normal; unknown public IPs are not"

# 7. Temp dirs ------------------------------------------------------------
section "7. New executables or PHP in temp dirs since $SINCE"
: > "$TMP/tmpd"
find /tmp /var/tmp /dev/shm -xdev -type f \( -perm -u+x -o -name '*.php' -o -name '*.so' \) -newermt "$SINCE" 2>/dev/null \
  | grep -vF "$TMP" | while IFS= read -r f; do
      inroot=0; for r in "${ROOTS[@]}"; do case "$f" in "$r"/*) inroot=1;; esac; done
      [ "$inroot" -eq 0 ] && echo "$f"
    done >> "$TMP/tmpd"
show "$TMP/tmpd" "droppers often stage in /tmp or /dev/shm"

# 8. Access-log heuristics -------------------------------------------------
section "8. Access-log heuristics"
: > "$TMP/logs"
for d in "${LOGS[@]}"; do
  for f in $(ls -1 "$d"/*access*log* "$d"/*.log "$d"/*/*access*log* 2>/dev/null | sort -u); do
    [ -f "$f" ] || continue
    case "$f" in *.gz) G_="zgrep";; *) G_="grep";; esac
    if [ -n "$LOG_HEURISTIC_REGEX" ]; then
      c=$($G_ -cE "$LOG_HEURISTIC_REGEX" "$f" 2>/dev/null); c=${c:-0}
      [ "$c" -gt 0 ] && echo "$f: $c request(s) matching advisory heuristic /$LOG_HEURISTIC_REGEX/" >> "$TMP/logs"
    fi
    c=$($G_ -cE '"POST [^"]*/(uploads|images|media|files|tmp)/[^"]*\.ph(p[0-9]?|tml|ar)' "$f" 2>/dev/null); c=${c:-0}
    [ "$c" -gt 0 ] && echo "$f: $c POST(s) to PHP files inside upload/media paths" >> "$TMP/logs"
  done
done
show "$TMP/logs" "heuristics only; open the log lines and check source IPs and response codes"

# 9. WordPress administrators ----------------------------------------------
section "9. WordPress administrator accounts"
: > "$TMP/wp"
WPC=$(for r in "${ROOTS[@]}"; do find "$r" -maxdepth 4 -name wp-config.php 2>/dev/null; done)
if [ -z "$WPC" ]; then
  echo "   no WordPress installs found"
elif [ "$WP" -eq 1 ] && command -v wp >/dev/null 2>&1; then
  while IFS= read -r c; do
    p=$(dirname "$c")
    echo "   $p"
    wp user list --role=administrator --fields=user_login,user_email,user_registered \
       --skip-plugins --skip-themes --path="$p" --allow-root 2>/dev/null | sed 's/^/      /'
    wp user list --role=administrator --field=user_registered --skip-plugins --skip-themes --path="$p" --allow-root 2>/dev/null \
      | awk -v s="$SINCE" '$1>=s' | sed "s|^|$p: admin registered |" >> "$TMP/wp"
  done <<< "$WPC"
  show "$TMP/wp" "administrators created since $SINCE"
else
  echo "$WPC" | sed 's/^/   found: /'
  echo "   Re-run with --wp (needs wp-cli) to list admins, or run per site:"
  echo "   wp user list --role=administrator --fields=user_login,user_registered --skip-plugins --skip-themes --path=<dir>"
fi

# ---- summary ---------------------------------------------------------------
printf '\n%s== Summary ==%s\n' "$BD" "$N"
if [ "$LEADS" -gt 0 ]; then
  printf '%s%d lead(s) to review.%s Do not delete anything yet: copy suspicious files and logs aside first (evidence), then follow the compromise-check skill.\n' "$Y$BD" "$LEADS" "$N"
else
  printf '%sNo leads found in the areas checked.%s That lowers, but does not rule out, the chance of compromise.\n' "$G$BD" "$N"
fi
printf 'Report saved: %s\n\n' "$OUTF"
[ "$LEADS" -gt 0 ] && exit 1 || exit 0
