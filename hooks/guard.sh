#!/usr/bin/env bash
# PreToolUse guard (Claude Code). Reads the tool call JSON on stdin.
#  - DENY fetching/running exploit or PoC code (pvr rule 4)
#  - ASK for any change that touches PHP / web stacks: package changes,
#    service restarts, deletions/moves in web roots, WordPress changes,
#    container redeploys. Read-only commands pass through untouched.
# Other harnesses rely on the same rules written in the skills.

IN=$(cat)
if command -v jq >/dev/null 2>&1; then
  CMD=$(printf '%s' "$IN" | jq -r '.tool_input.command // empty' 2>/dev/null)
elif command -v python3 >/dev/null 2>&1; then
  CMD=$(printf '%s' "$IN" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null)
else
  CMD=$IN
fi
[ -z "$CMD" ] && exit 0
LC=$(printf '%s' "$CMD" | tr 'A-Z' 'a-z')

decide() { # $1 deny|ask  $2 reason
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$1" "$2"
  exit 0
}

# 1. Exploit / PoC acquisition or execution
if echo "$LC" | grep -qE '(git clone|curl|wget|pip install|npm i|go install)[^|;&]*(poc|exploit|php2shell-cve|rce-)'; then
  decide deny "php-vuln-responder: fetching or running exploit/PoC code is not allowed. Verify by version and backport evidence instead."
fi

WEBCTX='php|fpm|apache|httpd|nginx|lsws|litespeed|frankenphp|ea-php|alt-php|/var/www|public_html|httpdocs|wp-content|wp-config|docker compose|docker-compose|plesk|custombuild'
echo "$LC" | grep -qE "$WEBCTX" || exit 0

if echo "$LC" | grep -qE '(apt(-get)?|dnf|yum|apk|zypper|brew)[[:space:]]+(-[a-z-]+[[:space:]]+)*(install|upgrade|update|remove|purge|erase|downgrade|dist-upgrade|full-upgrade|add|del|uninstall|history[[:space:]]+undo)|plesk installer|\./build[[:space:]]|xargs[^|]*apt-get install'; then
  decide ask "php-vuln-responder: package change on a PHP/web stack. Confirm backup taken and approve this exact command."
fi
if echo "$LC" | grep -qE 'systemctl[[:space:]]+(restart|stop|reload|disable)|service[[:space:]]+[^ ]+[[:space:]]+(restart|stop|reload)|restartsrv|rc-service|lswsctrl|apachectl[[:space:]]+(restart|stop|graceful)|nginx[[:space:]]+-s|octane:reload|horizon:terminate|supervisorctl[[:space:]]+(restart|stop)'; then
  decide ask "php-vuln-responder: service restart/stop on a PHP/web stack (brief downtime). Approve?"
fi
if echo "$LC" | grep -qE '(^|[;&|[:space:]])(rm|mv|shred|truncate|unlink|chmod|chown|sed[[:space:]]+-i|tee)[[:space:]]'; then
  decide ask "php-vuln-responder: this modifies files in a web/PHP location. Evidence must be copied first. Approve?"
fi
if echo "$LC" | grep -qE 'wp[[:space:]]+(core|plugin|theme|user|config|db)[[:space:]]+(install|update|delete|download|shuffle-salts|reset|import|create)|docker( compose|-compose)[[:space:]]+(up|down|build|restart|rm)'; then
  decide ask "php-vuln-responder: site or container change. Approve?"
fi
exit 0
