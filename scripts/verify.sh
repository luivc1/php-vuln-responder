#!/usr/bin/env bash
# =====================================================================
#  verify.sh  -  prove the patch actually took effect. READ-ONLY.
#
#  1. Re-scans every PHP binary on this host against the advisory.
#  2. Checks every running PHP process: if its binary was replaced on disk
#     after it started (shows as "(deleted)"), it is still running the OLD
#     vulnerable interpreter and must be restarted.
#  3. Optionally re-scans the public site(s) from outside.
#
#  Usage:  verify.sh [--url https://site ...] [--advisory file]
#  Exit:   0 PASS, 1 FAIL or needs attention
# =====================================================================

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"
ADV=""; URLS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --advisory) ADV="$2"; shift 2;;
    --url)      URLS+=("$2"); shift 2;;
    -h|--help)  sed -n '2,14p' "$0" | sed 's/^#//'; exit 0;;
    *) URLS+=("$1"); shift;;
  esac
done
load_advisory "$ADV"
FAIL=0; WARN=0
OUTDIR="${TMPDIR:-/tmp}/pvr-verify-$$"; mkdir -p "$OUTDIR"

printf '\n%s%s VERIFY%s\n' "$BD$C" "$ADVISORY_NAME" "$N"

printf '\n%s1. PHP binaries on this host%s\n' "$BD" "$N"
bash "$HERE/scan.sh" --local ${ADV:+--advisory "$ADV"} -o "$OUTDIR/local" | sed -n '/^[A-Z-]\{2,\} /,$p'
rc=${PIPESTATUS[0]}
[ "$rc" -ge 2 ] && FAIL=1
[ "$rc" -eq 1 ] && WARN=1

printf '\n%s2. Running PHP processes (stale interpreter check)%s\n' "$BD" "$N"
if [ -e /proc/self/exe ]; then
  stale=0; seen=0
  for p in /proc/[0-9]*; do
    exe=$(readlink "$p/exe" 2>/dev/null) || continue
    case "$(basename "${exe% (deleted)}")" in php*|lsphp*|frankenphp*) ;; *) continue;; esac
    seen=$((seen+1))
    if [[ $exe == *"(deleted)"* ]]; then
      stale=$((stale+1))
      printf '  %sSTALE%s pid %s  %s  %s\n' "$R$BD" "$N" "${p#/proc/}" "$exe" "$(tr '\0' ' ' < "$p/cmdline" | cut -c1-80)"
    fi
  done
  if [ "$stale" -gt 0 ]; then
    FAIL=1
    printf '  %s%d process(es) still run the replaced binary.%s Restart their service (php*-fpm, apache2/httpd, lsws, supervisor workers).\n' "$R" "$stale" "$N"
  else
    printf '  %sOK%s  %d PHP process(es) checked, none running a replaced binary.\n' "$G" "$N" "$seen"
  fi
else
  printf '  %sSKIPPED%s (no /proc on this OS). Restart PHP services after upgrading to be safe.\n' "$Y" "$N"
fi

if [ ${#URLS[@]} -gt 0 ]; then
  printf '\n%s3. Public view of the site(s)%s\n' "$BD" "$N"
  bash "$HERE/scan.sh" ${ADV:+--advisory "$ADV"} -o "$OUTDIR/remote" "${URLS[@]}" | sed -n '/^[A-Z-]\{2,\} /,$p'
  rc=${PIPESTATUS[0]}
  [ "$rc" -ge 2 ] && FAIL=1
  printf '  %s(HIDDEN is normal for hardened sites; the host-side checks above are the real proof.)%s\n' "$D" "$N"
fi

printf '\n'
if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 1 ]; then
  printf '%sCONFIRM%s  Nothing confirmed vulnerable, but some builds are unverified distro/vendor versions (CHECK). Confirm the backport (package changelog or vendor advisory) before closing.\n\n' "$Y$BD" "$N"
  FAIL=1
elif [ "$FAIL" -eq 0 ]; then
  printf '%sPASS%s  No vulnerable binaries and no stale PHP processes found.\n\n' "$G$BD" "$N"
else
  printf '%sFAIL%s  Something still needs attention (see above).\n\n' "$R$BD" "$N"
fi
rm -rf "$OUTDIR"
exit "$FAIL"
