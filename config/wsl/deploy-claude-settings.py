#!/usr/bin/env python3
# deploy-claude-settings.py - render the settings fragment into the WSL root's
# Claude Code config. Invoked from wsl-setup.sh's deploy-config step:
#
#   python3 $CFG/deploy-claude-settings.py <fragment.json> </root/.claude/settings.json> [WIN_USER]
#
# Merge with the same semantics as install.ps1's Sync-SettingsFragments (kept step with
# it deliberately; a comment change here must be mirrored there):
#
#   - stored is read BEFORE merge(): merge() setdefaults the fragment's
#     _hbFragmentVersion into the live data, so reading it afterwards always
#     yielded the new value and the version gate silently no-opped. The same
#     defect, found the same way, was fixed in install.ps1's
#     Sync-SettingsFragments; both implementations must stay in step.
#   - The fragment version is stamped unconditionally so a downgrade cannot
#     make an old fragment re-apply forever.
#   - overrideKeys/deleteKeys are merge machinery: never merged into the live
#     file; deleteKeys is consumed at the version gate like apply_overrides,
#     because a merged key can never delete a dead one.
#   - ANTHROPIC_AUTH_TOKEN is a live-owned secret: it is not in overrideKeys,
#     so a real key on an updating machine can never be clobbered by the
#     fragment's placeholder. Fresh machines receive the placeholder and get
#     a real key via opencode-key-setup.ps1.
#
# WSL differences from the Windows apply: the fragment's `hooks` key is
# dropped (its commands are Windows-shelled paths that do not run in WSL
# Claude Code); everything else - env block, aliases, modelPicker, default
# model - ships as-is. Live keys the fragment does not carry (such as the
# MCP servers registered on this machine) survive the setdefault merge.
import json, os, shutil, sys

frag_path, dst_path = sys.argv[1], sys.argv[2]
win_user = sys.argv[3] if len(sys.argv) > 3 else ""

with open(frag_path, encoding="utf-8") as fh:
    frag_text = fh.read()
for token in ("{{WIN_USER}}", "{{USER_FULL_NAME}}"):
    frag_text = frag_text.replace(token, win_user)
frag = json.loads(frag_text)
frag.pop("hooks", None)

data = {}
if os.path.exists(dst_path):
    shutil.copy2(dst_path, dst_path + ".bak-harness-bundle")
    with open(dst_path, encoding="utf-8") as fh:
        data = json.load(fh)

def merge(a, b):
    for k, v in b.items():
        if k in ("_hbFragmentVersion", "overrideKeys", "deleteKeys"):
            continue
        if isinstance(v, dict) and isinstance(a.get(k), dict):
            merge(a[k], v)
        elif isinstance(v, list) and isinstance(a.get(k), list):
            a[k] = a[k] + [x for x in v if x not in a[k]]
        else:
            a.setdefault(k, v)

def apply_overrides(a, b, overrides):
    # fragment-wins for keys explicitly listed in overrideKeys (dot paths)
    for path in overrides:
        keys = path.split('.')
        src, dst = b, a
        ok = True
        for k in keys[:-1]:
            if not isinstance(src.get(k), dict) or not isinstance(dst.get(k), dict):
                ok = False; break
            src, dst = src[k], dst[k]
        if ok and keys[-1] in src:
            dst[keys[-1]] = src[keys[-1]]

def apply_deletions(a, paths):
    # A fragment can only ever set a key, never remove one; dead keys (a
    # retired pin, a stale discovery flag, a leftover ANTHROPIC_API_KEY) would
    # otherwise survive every later fragment forever.
    for path in paths:
        keys = path.split('.')
        parent = a
        ok = True
        for k in keys[:-1]:
            if not isinstance(parent, dict) or not isinstance(parent.get(k), dict):
                ok = False; break
            parent = parent[k]
        if ok and isinstance(parent, dict):
            parent.pop(keys[-1], None)

stored = data.get('_hbFragmentVersion', 0)
merge(data, frag)
fragVer = frag.get('_hbFragmentVersion', 1)
if fragVer > stored:
    apply_overrides(data, frag, frag.get('overrideKeys', []))
    apply_deletions(data, frag.get('deleteKeys', []))
# Stamp unconditionally: a downgrade must not let an old fragment re-apply.
data['_hbFragmentVersion'] = fragVer
for k in ('overrideKeys', 'deleteKeys'):
    data.pop(k, None)

with open(dst_path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
print("merged", os.path.basename(frag_path), "->", dst_path, "(v%s)" % data.get('_hbFragmentVersion'))
