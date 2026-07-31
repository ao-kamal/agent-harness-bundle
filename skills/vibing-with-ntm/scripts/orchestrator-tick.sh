#!/usr/bin/env bash
# orchestrator-tick.sh — terse, one-screen snapshot for deciding a tick's action
#
# Usage: orchestrator-tick.sh <session> [repo_path]
# Example: orchestrator-tick.sh asupersync /data/projects/asupersync
#
# Prints:
#   - source_health (from --robot-snapshot)
#   - per-pane is_working + is_rate_limited + is_context_low
#   - rate-limit / OAuth truth
#   - stuck-pane dry-run
#   - triage quick_ref
#   - commits in last hour (productivity ground truth)
#   - in-flight + claimed bead counts (including the often-missed `claimed`)
#
# Per /vibing-with-ntm Operator Loop + OC-012 (source-health first) + OC-005 (track claimed).

set -u
SESSION="${1:?usage: orchestrator-tick.sh <session> [repo_path]}"
REPO="${2:-$PWD}"

hr() { printf '── %s ──\n' "$*"; }

hr "SOURCE HEALTH"
ntm --robot-snapshot 2>/dev/null \
  | jq -r '((.sources.sources // .source_health) // {}) | to_entries[] | "  \(.key): \(if (.value.available // (.value.status=="ok")) then "ok" else "DOWN" end) fresh=\(.value.fresh // "?") age=\(((.value.age_ms // 0)/1000)|floor)s"' \
  || echo "  (snapshot unavailable — cursor may be expired; rerun --robot-snapshot)"

hr "PANES · is_working / is_rate_limited / is_context_low"
ntm --robot-is-working="$SESSION" 2>/dev/null \
  | jq -r '(.panes // {}) | to_entries[] | "  p\(.key): working=\(.value.is_working // false) rate_limited=\(.value.is_rate_limited // false) ctx_low=\(.value.is_context_low // false) conf=\(.value.confidence // "?")"' \
  || echo "  (--robot-is-working unavailable)"

hr "OAUTH / RATE-LIMIT TRUTH"
ntm --robot-health-oauth="$SESSION" 2>/dev/null \
  | jq -r '(.agents // .panes // []) | .[] | "  p\(.pane): provider=\(.provider) rate_limit=\(.rate_limit_status // .rate_limited // "?") oauth=\(.oauth_status // "-") cooldown=\(.cooldown_remaining // 0)s"' \
  || echo "  (oauth health unavailable)"

hr "STUCK-PANE DRY-RUN (10m threshold)"
ntm --robot-health-restart-stuck="$SESSION" --stuck-threshold=10m --dry-run 2>/dev/null \
  | jq -r '.stuck_panes[]? | "  p\(.pane // .pane_index // "?"): stuck=\(.stuck_for // .stuck_for_sec // .stuck_seconds // "?")s reason=\(.reason // .why // "-")"' \
  || true

hr "BV QUICK-REF (from --robot-triage)"
bv --robot-triage 2>/dev/null | jq -r '((.triage.quick_ref // .quick_ref) // {}) as $q | if (($q|type)=="object") and (($q|length)>0) then "  open=\($q.open_count) actionable=\($q.actionable_count) blocked=\($q.blocked_count) in_progress=\($q.in_progress_count)" else "  (bv --robot-triage failed)" end'

hr "PRODUCTIVITY · git log last 1h"
COMMITS=$(git -C "$REPO" log --since="1 hour ago" --oneline 2>/dev/null | wc -l | tr -d ' ')
echo "  commits_1h=$COMMITS"
git -C "$REPO" log --since="1 hour ago" --format='  %ar %an %h %s' 2>/dev/null | head -5

hr "BEAD STATE · open + claimed + in_progress"
OPEN=$(br list --status=open --json 2>/dev/null | jq 'if type=="object" then .issues else . end | length')
CLAIMED=$(br list --status=claimed --json 2>/dev/null | jq 'if type=="object" then .issues else . end | length')
IP=$(br list --status=in_progress --json 2>/dev/null | jq 'if type=="object" then .issues else . end | length')
READY=$(br ready --json 2>/dev/null | jq 'if type=="object" then .issues else . end | length')
echo "  open=$OPEN  claimed=$CLAIMED  in_progress=$IP  ready=$READY  (total backlog=$((OPEN+CLAIMED+IP)))"

hr "SUGGESTED NEXT ACTION"
if [ "$COMMITS" -eq 0 ] && [ "$READY" -eq 0 ] && [ "$((IP+CLAIMED))" -eq 0 ]; then
  echo "  ⮕ CONVERGED candidate — verify with convergence-check.sh then STOP"
elif [ "$((OPEN+CLAIMED+IP))" -gt 100 ]; then
  echo "  ⮕ BACKLOG >100 — dispatch close-the-backlog prompt; block new review beads"
elif [ "$COMMITS" -eq 0 ]; then
  echo "  ⮕ No commits in 1h — scan for prose-without-commits (OC-004) or handoff-failure (OC-036)"
else
  echo "  ⮕ Healthy pace — specific-terse nudges to idle panes only (OC-010)"
fi
