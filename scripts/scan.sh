#!/usr/bin/env bash
# =====================================================================
#  scan.sh  -  passive PHP exposure scanner (advisory driven)
#
#  READ-ONLY. One ordinary page request per site. No exploit payloads,
#  no fuzzing, no logins. Only scan sites you own or are authorized to
#  assess.
#
#  Usage:
#    scan.sh example.com shop.example.com
#    scan.sh -f sites.txt -o out/clientA      # -> out/clientA.csv + .html
#    scan.sh --local                          # run ON the server
#    scan.sh --advisory advisories/next.env -f sites.txt
#
#  Statuses: PATCHED | VULNERABLE | EOL | CHECK | HIDDEN | NO-PHP | ERROR
#  Exit codes: 0 all clear, 1 manual check needed, 2 at-risk found, 3 usage error
# =====================================================================

. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

TIMEOUT="${TIMEOUT:-12}"
UA="Mozilla/5.0 (compatible; php-vuln-responder/1.0; passive version audit)"
TMP=$(mktemp -d 2>/dev/null || mktemp -d -t pvr)
trap 'rm -rf "$TMP"' EXIT

ROWS=(); WORST=0
CNT_RISK=0; CNT_CHK=0; CNT_OK=0; CNT_OTH=0

usage() { sed -n '2,18p' "$0" | sed 's/^#//'; exit 0; }

record() { # target version status note signals
  ROWS+=("$1|$2|$3|$4|$5")
  local col lvl
  case "$3" in
    PATCHED)            col=$G; lvl=0; CNT_OK=$((CNT_OK+1));;
    VULNERABLE|EOL)     col=$R; lvl=2; CNT_RISK=$((CNT_RISK+1));;
    CHECK|HIDDEN|ERROR) col=$Y; lvl=1; CNT_CHK=$((CNT_CHK+1));;
    *)                  col=$D; lvl=0; CNT_OTH=$((CNT_OTH+1));;
  esac
  (( lvl > WORST )) && WORST=$lvl
  printf '%s%-11s%s %s%s%s\n' "$col$BD" "$3" "$N" "$BD" "$1" "$N"
  printf '            PHP: %s\n' "${2:--}"
  printf '            %s\n' "$4"
  [ -n "$5" ] && printf '            %s%s%s\n' "$D" "$5" "$N"
  echo
}

esc()  { printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'; }
csvq() { local s=${1//\"/\"\"}; printf '"%s"' "$s"; }

write_csv() {
  local f="$1.csv" r t v s n g
  echo 'target,php_version,status,note,signals,advisory' > "$f"
  for r in "${ROWS[@]}"; do
    IFS='|' read -r t v s n g <<< "$r"
    printf '%s,%s,%s,%s,%s,%s\n' "$(csvq "$t")" "$(csvq "$v")" "$(csvq "$s")" "$(csvq "$n")" "$(csvq "$g")" "$(csvq "$ADVISORY_ID")" >> "$f"
  done
}

write_html() {
  local f="$1.html" r t v s n g cls card risk="" chk="" ok="" oth="" when chips="" x
  when=$(date '+%Y-%m-%d %H:%M %Z')
  for x in $FIXED_VERSIONS; do chips="$chips<span class=\"chip\">$x</span>"; done
  for r in "${ROWS[@]}"; do
    IFS='|' read -r t v s n g <<< "$r"
    case "$s" in
      VULNERABLE|EOL) cls=risk;; CHECK|HIDDEN|ERROR) cls=chk;; PATCHED) cls=ok;; *) cls=oth;;
    esac
    card="<div class=\"card $cls\"><div class=\"top\"><span class=\"badge\">$(esc "$s")</span><span class=\"ver\">PHP $(esc "${v:--}")</span></div><h3>$(esc "$t")</h3><p>$(esc "$n")</p>"
    [ -n "$g" ] && card="$card<p class=\"sig\">$(esc "$g")</p>"
    card="$card</div>"
    case "$cls" in risk) risk="$risk$card";; chk) chk="$chk$card";; ok) ok="$ok$card";; *) oth="$oth$card";; esac
  done
  cat > "$f" <<HTML
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>$(esc "$ADVISORY_NAME") Report</title>
<style>
:root{--bg:#f6f7f9;--fg:#14161a;--mut:#5d6470;--card:#fff;--line:#e3e6eb;--risk:#d92d20;--chk:#dc8a00;--ok:#16a34a;--oth:#7a828e}
@media (prefers-color-scheme:dark){:root{--bg:#0f1115;--fg:#eef0f3;--mut:#9aa3af;--card:#181b21;--line:#2a2f37}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,-apple-system,Segoe UI,Roboto,sans-serif;padding:24px 16px}
.wrap{max-width:1000px;margin:0 auto}h1{margin:0 0 4px;font-size:24px}.sub{color:var(--mut);margin:0 0 18px;font-size:13px}
.chips{display:flex;flex-wrap:wrap;gap:8px;margin-bottom:18px;align-items:center}.chip{border:1px solid var(--line);background:var(--card);border-radius:999px;padding:4px 12px;font-size:13px}
.sum{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px;margin-bottom:24px}
.stat{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:14px 16px;border-top:5px solid var(--c)}
.stat b{display:block;font-size:30px;line-height:1.1;color:var(--c)}.stat span{color:var(--mut);font-size:13px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(290px,1fr));gap:14px}
.card{background:var(--card);border:1px solid var(--line);border-left:6px solid var(--c);border-radius:14px;padding:14px 16px;min-width:0}
.card h3{margin:8px 0 6px;font-size:16px;word-break:break-all}.card p{margin:0 0 6px;font-size:14px}.sig{color:var(--mut);font-size:12px!important;word-break:break-word}
.top{display:flex;justify-content:space-between;align-items:center;gap:8px}.badge{background:var(--c);color:#fff;font-weight:700;font-size:11px;letter-spacing:.06em;padding:3px 9px;border-radius:6px}
.ver{font-family:ui-monospace,Menlo,Consolas,monospace;font-size:13px;color:var(--mut)}
.risk{--c:var(--risk)}.chk{--c:var(--chk)}.ok{--c:var(--ok)}.oth{--c:var(--oth)}
footer{color:var(--mut);font-size:12px;margin-top:28px}
</style></head><body><div class="wrap">
<h1>$(esc "$ADVISORY_NAME") exposure report</h1>
<p class="sub">$(esc "$CVES") &middot; generated $when &middot; passive check (version fingerprints only)</p>
<div class="chips"><b style="font-size:13px">Fixed:</b>$chips<span class="chip">Older than $(esc "$EOL_BELOW"): no fix (EOL)</span></div>
<div class="sum">
<div class="stat risk"><b>$CNT_RISK</b><span>At risk (vulnerable / EOL)</span></div>
<div class="stat chk"><b>$CNT_CHK</b><span>Needs manual check</span></div>
<div class="stat ok"><b>$CNT_OK</b><span>Patched</span></div>
<div class="stat oth"><b>$CNT_OTH</b><span>No PHP seen</span></div>
</div>
<div class="grid">$risk$chk$ok$oth</div>
<footer>A remote check reads only what the server reveals. "Patched" means the advertised version is fixed; "No PHP seen" is not proof of safety. Confirm on the server with --local or the hosting panel. Advisory: $(esc "$ADVISORY_ID"), last verified $(esc "$LAST_VERIFIED").</footer>
</div></body></html>
HTML
}

scan_url() {
  local target="$1" url h="$TMP/h" b="$TMP/b" xpb srv ver sig="" ck
  url="$target"
  case "$url" in http://*|https://*) ;; *) url="https://$url";; esac
  : > "$h"; : > "$b"
  curl -sS -L --max-redirs 5 -m "$TIMEOUT" -A "$UA" -D "$h" "$url" 2>"$TMP/err" | head -c 400000 > "$b"
  if [ ! -s "$h" ]; then
    record "$target" "" "ERROR" "No response: $(head -1 "$TMP/err" | tr -d '|')" ""
    return
  fi

  xpb=$(grep -i '^x-powered-by:' "$h" | tail -1 | cut -d: -f2- | tr -d '\r' | sed 's/^ *//')
  srv=$(grep -i '^server:' "$h" | tail -1 | cut -d: -f2- | tr -d '\r' | sed 's/^ *//')
  ver=$(printf '%s %s' "$xpb" "$srv" | grep -oiE 'PHP/[0-9]+\.[0-9]+(\.[0-9]+)?[^ ;,)]*' | head -1 | cut -d/ -f2)

  [ -n "$xpb" ] && sig="$sig X-Powered-By: $xpb;"
  ck=$(grep -i '^set-cookie:' "$h" | tr 'A-Z' 'a-z')
  echo "$ck" | grep -q 'phpsessid'               && sig="$sig PHPSESSID cookie;"
  echo "$ck" | grep -q 'laravel_session'         && sig="$sig Laravel session;"
  echo "$ck" | grep -qE 'wordpress_|wp-settings' && sig="$sig WordPress cookie;"
  grep -qi '^x-drupal' "$h"                      && sig="$sig Drupal header;"
  grep -qiE '/wp-content/|/wp-includes/' "$b"    && sig="$sig WordPress assets;"
  grep -qiE 'name="generator"[^>]*(wordpress|drupal|joomla)' "$b" && sig="$sig CMS generator tag;"
  grep -qiE 'mage-cache|Magento_' "$b"           && sig="$sig Magento assets;"
  grep -qiE 'href="[^"]*\.php' "$b"              && sig="$sig .php links;"
  sig=$(echo "$sig" | sed 's/^ *//; s/;$//')

  if [ -n "$ver" ]; then
    classify "$ver"
    record "$target" "$ver" "$STATUS" "$NOTE" "$sig"
  elif [ -n "$sig" ]; then
    record "$target" "hidden" "HIDDEN" "PHP detected but version is hidden. Confirm on the server (--local) or ask the host which PHP version runs this site." "$sig"
  else
    record "$target" "" "NO-PHP" "No PHP fingerprints from outside. Not proof of safety if a proxy or CDN masks the stack." "${srv:+Server: $srv}"
  fi
}

local_scan() {
  local b ver pk up sapi host bins
  host=$(hostname 2>/dev/null || uname -n)
  bins=$(discover_php_bins)
  if [ -z "$bins" ]; then
    record "$host" "" "NO-PHP" "No PHP binaries found in common locations." ""
    return
  fi
  while IFS= read -r b; do
    ver=$(php_bin_version "$b")
    if [ -z "$ver" ]; then record "$host:$b" "" "ERROR" "Could not read version from this binary." ""; continue; fi
    sapi=$("$b" -v </dev/null 2>/dev/null | head -1 | grep -oE '\((cli|fpm-fcgi|cgi-fcgi|litespeed|apache2handler)\)' | tr -d '()')
    up=$("$b" -i </dev/null 2>/dev/null | grep -m1 '^session.upload_progress.enabled' | awk -F'=> ' '{print $2}' | tr -d ' ')
    pk=$(owning_package "$b")
    classify_installed "$ver" "$pk"
    record "$host:$b" "$ver${pk:+ [pkg $pk]}" "$STATUS" "$NOTE" "SAPI: ${sapi:-?}; session.upload_progress.enabled=${up:-n/a}"
  done <<< "$bins"
  printf '%sNote:%s the CLI version can differ from what the web server runs. Use detect-stack.sh and verify.sh to confirm the web-facing PHP.\n\n' "$Y" "$N"
}

FILE=""; OUT="php-scan-report"; LOCAL=0; TARGETS=(); ADV=""
while [ $# -gt 0 ]; do
  case "$1" in
    -f|--file)     FILE="$2"; shift 2;;
    -o|--out)      OUT="$2";  shift 2;;
    --advisory)    ADV="$2";  shift 2;;
    --local)       LOCAL=1;   shift;;
    -h|--help)     usage;;
    -*)            echo "Unknown option: $1"; exit 3;;
    *)             TARGETS+=("$1"); shift;;
  esac
done
load_advisory "$ADV"

if [ -n "$FILE" ]; then
  [ -r "$FILE" ] || { echo "Cannot read $FILE"; exit 3; }
  while IFS= read -r line || [ -n "$line" ]; do
    line=$(printf '%s' "$line" | tr -d '\r' | sed 's/#.*//; s/^[[:space:]]*//; s/[[:space:]]*$//')
    [ -n "$line" ] && TARGETS+=("$line")
  done < "$FILE"
fi

if [ "$LOCAL" -eq 0 ] && [ ${#TARGETS[@]} -eq 0 ]; then usage; fi
if [ ${#TARGETS[@]} -gt 0 ] && ! command -v curl >/dev/null 2>&1; then echo "curl is required for remote scans"; exit 3; fi
mkdir -p "$(dirname "$OUT")" 2>/dev/null

banner
[ "$LOCAL" -eq 1 ] && local_scan
for t in "${TARGETS[@]}"; do scan_url "$t"; done

write_csv "$OUT"; write_html "$OUT"
printf '%sSummary:%s %s%d at risk%s, %s%d need checking%s, %s%d patched%s, %d no PHP seen\n' \
  "$BD" "$N" "$R" "$CNT_RISK" "$N" "$Y" "$CNT_CHK" "$N" "$G" "$CNT_OK" "$N" "$CNT_OTH"
printf 'Report: %s.html  |  %s.csv\n\n' "$OUT" "$OUT"
exit "$WORST"
