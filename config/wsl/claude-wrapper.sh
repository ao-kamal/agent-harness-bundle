#!/bin/bash
# Wrapper: auto-trust cwd before launching real claude
REAL_CLAUDE=/root/.local/bin/claude
[ -x "$REAL_CLAUDE" ] || { echo "claude not found at $REAL_CLAUDE" >&2; exit 1; }

CWD="$(pwd)"
python3 - "$CWD" <<'PY' 2>/dev/null
import json, os, sys
cwd = sys.argv[1]
p = "/root/.claude.json"
if not os.path.exists(p):
    with open(p, "w") as f: json.dump({"projects":{}}, f)
with open(p) as f: d = json.load(f)
proj = d.setdefault("projects", {}).setdefault(cwd, {})
proj["hasTrustDialogAccepted"] = True
proj["hasClaudeMdExternalIncludesApproved"] = True
proj["hasClaudeMdExternalIncludesWarningShown"] = True
proj.setdefault("allowedTools", [])
proj.setdefault("mcpContextUris", [])
proj.setdefault("mcpServers", {})
proj.setdefault("enabledMcpjsonServers", [])
proj.setdefault("disabledMcpjsonServers", [])
with open(p, "w") as f:
    json.dump(d, f, indent=2)
    f.flush()
    os.fsync(f.fileno())
PY

exec "$REAL_CLAUDE" "$@"
