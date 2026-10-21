---
description: Verify the patch took effect (binaries, stale processes, public re-scan) and close out
argument-hint: "[https://site ...]"
---
Use the pvr-verify-close skill with PVR=${CLAUDE_PLUGIN_ROOT}. Sites to re-scan: $ARGUMENTS
For fleets of client sites, delegate the verification to the pvr-verifier agent so it is independent of the patch work.
