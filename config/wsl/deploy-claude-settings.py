#!/usr/bin/env python3
# deploy-claude-settings.py - render the settings fragment into the WSL root's
# Claude Code config. Invoked from wsl-setup.sh's deploy-config step:
#
#   python3 $CFG/deploy-claude-settings.py <fragment.json> </root/.claude/settings.json> [WIN_USER]
#
# Same merge semantics as install.ps1's embedded version (kept in step with
# it deliberately; a comment change here must be mirrored there):
#
#   - `stored` is read BEFORE merge(): merge() setdefaults the fragment's
#     _hbFragmentVersion into the live data, so reading it afterwards yields
#     stored == fragVer and the gate silently no-ops. Caught by reproduction
#     on 2026-10-29.
#   - overrideKeys: fragment-wins dot paths, only when the fragment version
#     is newer than the stored one.
#   - removedKeys: dot paths deleted from live at the same version gate.
#   - ANTHROPIC_AUTH_TOKEN is a live-owned secret: it is not in overrideKeys,
#     so a real key on an updating machine can never be clobbered by the
#     fragment's placeholder. Fresh machines receive the placeholder and get
#     a real key via secrets-setup.ps1.
#   - overrideKeys/removedKeys are merge machinery and are stripped from the
#     live file every run.
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
        if isinstance(v, dict) and isinstance(a.get(k), dict):
            merge(a[k], v)
        elif isinstance(v, list) and isinstance(a.get(k), list):
            a[k] = a[k] + [x for x in v if x not in a[k]]
        else:
            a.setdefault(k, v)

def apply_overrides(a, b, overrides):
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

def drop_paths(a, overrides):
    for path in overrides:
        keys = path.split('.')
        src = a
        ok = True
        for k in keys[:-1]:
            if not isinstance(src, dict) or not isinstance(src.get(k), dict):
                ok = False; break
            src = src[k]
        if ok and isinstance(src, dict) and keys[-1] in src:
            del src[keys[-1]]

stored = data.get('_hbFragmentVersion', 0)
merge(data, frag)
fragVer = frag.get('_hbFragmentVersion', 1)
if fragVer > stored:
    apply_overrides(data, frag, frag.get('overrideKeys', []))
    drop_paths(data, frag.get('removedKeys', []))
    data['_hbFragmentVersion'] = fragVer
for k in ('overrideKeys', 'removedKeys'):
    data.pop(k, None)

with open(dst_path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
print("merged", os.path.basename(frag_path), "->", dst_path, "(v%s)" % data.get('_hbFragmentVersion'))
