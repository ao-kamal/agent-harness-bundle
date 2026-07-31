---
name: browser-testing-with-ntm
description: >-
  Coordinate NTM browser-testing swarms using agent-browser, next-browser,
  Playwright, React DevTools, Beads, and Agent Mail. Use when running parallel
  exploratory QA, visual/UX audits, Next.js runtime inspection, React profiling,
  browser evidence collection, or turning browser findings into beads.
category: testing
tags:
  - ctx-web
  - ctx-testing
  - ctx-cli
  - fw-react
  - lang-typescript
license: MIT
distribution: public
---

# Browser Testing With NTM

Use this skill when a single browser QA pass is not enough and you want an
NTM-tended swarm to test a web app through multiple evidence channels at once:

- `agent-browser` for real headed interaction and accessibility snapshots.
- `next-browser` for Next.js errors, route segments, component tree, logs, and
  network evidence.
- Playwright for deterministic E2E, screenshots, traces, mobile breakpoints, and
  repeatable regression harnesses.
- `agent-react-devtools` for React component props/state/hooks and profiling.
- UX/a11y review for visual polish, keyboard flow, contrast, cognitive load, and
  error-state quality.
- Beads/Agent Mail for coordination, deduping, ownership, and follow-up work.

This skill combines the operational discipline of `vibing-with-ntm` with the
browser-specific testing method from `e2e-testing-for-webapps`, `agent-browser`,
`next-browser`, `react-devtools`, `ui-polish`, and `ux-audit`.

## Decision Rule

Run this skill when the ask includes any of:

- "use several agents to test the app"
- "parallel browser QA"
- "agent-browser and next-browser together"
- "have NTM panes test different routes"
- "find UX bugs and turn them into beads"
- "profile React while another agent drives the UI"
- "visual QA swarm"
- "browser testing runbook"

Skip this skill when:

- You only need one quick Playwright command.
- The app cannot build at all and no browser can render product UI. In that case,
  create/fix the build blocker first, then come back.
- The user asked for implementation, not QA orchestration.
- The repo forbids multiple agents or requires a different coordination model.

## Core Principle

Split by evidence channel, not by "everyone click around." Browser swarms work
when each pane has a narrow job, unique browser state, and a shared evidence
contract. They fail when all agents open the same route, file duplicate findings,
or create noisy beads from one screenshot.

The coordinator owns triage and bead creation. Test agents own evidence.

## Preflight

Do this before spawning or dispatching any browser-testing swarm.

### 1. Read repo rules

From the target repo root:

```bash
test -f AGENTS.md && sed -n '1,220p' AGENTS.md
test -f README.md && sed -n '1,180p' README.md
```

Extract:

- How to start the dev server.
- Which URL/port to use.
- Whether login is required.
- Test-user credentials or storage-state setup.
- Required browser tools.
- Beads/Agent Mail reservation rules.
- Any "do not mutate tracker" or "planning only" constraints.

### 2. Check the worktree and tracker

```bash
git status --short
br sync --status --json
br list --status open --json
br list --status in_progress --json
br dep cycles
bv --robot-triage
```

If the repo uses Agent Mail reservations:

```bash
am robot status --project "$PWD" --format json
am robot reservations --project "$PWD" --format json
```

Only one coordinator should reserve `.beads/**` and write tracker findings.
Browser test agents should report findings, not mutate beads, unless explicitly
assigned to a bead.

### 3. Confirm the app is actually running

```bash
lsof -nP -iTCP:3000 -sTCP:LISTEN || true
curl -I --max-time 5 http://localhost:3000/ || true
ps -axo pid,ppid,command | rg 'next dev|npm run dev|vite|webpack|turbopack'
```

Do not start a duplicate dev server if one already owns the port. If the repo
has a host-run command such as `npm run dev:host`, prefer that over raw framework
commands.

### 4. Load browser command docs

For `agent-browser`, always load the installed command guide before using it:

```bash
agent-browser skills get core
```

For `next-browser`, check the installed version and use project-root commands:

```bash
next-browser --version
npm view @vercel/next-browser version
```

For Next.js work, if bundled docs exist, read the relevant version-matched docs
under `node_modules/next/dist/docs/` before coding or making architectural claims.

### 5. Set browser isolation variables

Each browser agent gets a unique session name. On macOS or CAAM-style isolated
homes, long default socket paths can break browser daemons. Prefer short socket
roots:

```bash
export AGENT_BROWSER_SOCKET_DIR=/tmp/ab
export NEXT_BROWSER_HOME=/tmp/nb
```

If `next-browser` under a temporary HOME cannot find Playwright browsers, link to
the real browser cache or run the documented install command:

```bash
mkdir -p /tmp/nb/Library/Caches
ln -sfn "$HOME/Library/Caches/ms-playwright" /tmp/nb/Library/Caches/ms-playwright
```

In CAAM, the real user cache may be outside the isolated HOME. Inspect before
assuming:

```bash
find "$HOME/Library/Caches/ms-playwright" /Users/*/Library/Caches/ms-playwright \
  -maxdepth 3 -name 'Google Chrome for Testing.app' 2>/dev/null | head
```

## Role Lanes

Assign one clear lane per pane. The coordinator may be a human, a Codex pane, or
an NTM controller, but the coordinator should not also be the busiest browser
driver.

### Lane A: Coordinator and bead writer

Responsibilities:

- Read repo rules.
- Check `br`, `bv`, Agent Mail, reservations, and worktree state.
- Assign route/tool lanes.
- Maintain the route matrix and avoid-list.
- Deduplicate findings.
- Create or update beads only after evidence is strong.
- Stop the swarm when findings converge.

Tools:

```bash
ntm --robot-snapshot
ntm --robot-is-working=<session>
ntm --robot-agent-health=<session>
ntm coordinator digest <session>
ntm locks list <session> --all-agents
bv --robot-triage
br list --status open,in_progress,claimed --json
```

### Lane B: agent-browser exploratory driver

Responsibilities:

- Use headed browser sessions for realistic interaction.
- Log in like a user.
- Navigate, click, fill forms, hover, tab, open menus, and take screenshots.
- Prefer accessibility-tree refs and semantic locators.
- Report routes, steps, expected/actual behavior, screenshots, and console-visible
  overlays.

Starter:

```bash
agent-browser skills get core
AGENT_BROWSER_SOCKET_DIR=/tmp/ab agent-browser --session qa1 --headed open http://localhost:3000/login
AGENT_BROWSER_SOCKET_DIR=/tmp/ab agent-browser --session qa1 snapshot -i -u
```

Rules:

- Re-snapshot after every page-changing action.
- Use headed mode when React DevTools or user-observable rendering matters.
- Use one browser session per pane.
- Save screenshots for visual findings.

### Lane C: next-browser runtime inspector

Responsibilities:

- Inspect Next.js build/runtime errors.
- Capture route segments and layout/page ownership.
- Inspect React component tree via Next browser integration.
- Inspect network requests and server action headers.
- Check logs and dev overlay errors after each route.

Starter:

```bash
cd path/to/next-app
HOME=/tmp/nb NEXT_BROWSER_HOME=/tmp/nb next-browser open http://localhost:3000/dashboard
HOME=/tmp/nb NEXT_BROWSER_HOME=/tmp/nb next-browser errors
HOME=/tmp/nb NEXT_BROWSER_HOME=/tmp/nb next-browser page
HOME=/tmp/nb NEXT_BROWSER_HOME=/tmp/nb next-browser network
HOME=/tmp/nb NEXT_BROWSER_HOME=/tmp/nb next-browser tree | head -120
```

Rules:

- Run from the Next.js app directory.
- Check `errors` before judging visual state.
- Treat build overlays as P0/P1 blockers; do not bury them under UX findings.
- Use `network <idx>` to inspect suspicious redirects, 401s, 500s, and server
  action responses.

### Lane D: Playwright regression and evidence owner

Responsibilities:

- Run existing E2E/smoke/demo QA scripts.
- Capture trace, video, screenshots, and failure context.
- Verify responsive breakpoints.
- Create repeatable scripts/spec updates only when assigned.

Starter:

```bash
PLAYWRIGHT_BASE_URL=http://127.0.0.1:3000 \
PLAYWRIGHT_E2E_EMAIL=testuser1@example.com \
PLAYWRIGHT_E2E_PASSWORD=test123 \
npm run test:e2e:demo-qa
```

Rules:

- Use real Playwright actions (`click`, `fill`, `press`) for signoff paths.
- Do not replace user interactions with `page.evaluate()` except for diagnostics.
- Preserve trace/video paths in findings.
- Separate functional failure from visual quality findings.

### Lane E: React DevTools profiler

Responsibilities:

- Confirm `agent-react-devtools` can connect.
- Inspect component tree, props, state, hooks.
- Profile slow interactions.
- Compare render counts before/after fixes.

Starter:

```bash
agent-react-devtools status
agent-react-devtools start
agent-react-devtools wait --connected --timeout 10
agent-react-devtools get tree --depth 3
agent-react-devtools profile start qa-interaction
# another lane drives the UI here
agent-react-devtools profile stop
agent-react-devtools profile slow --limit 10
agent-react-devtools profile rerenders --limit 10
```

Rules:

- If status shows no connected app, do not pretend profiling happened.
- Use headed browser sessions when driving with `agent-browser`.
- If the app is not instrumented, create a tooling finding with dry-run output and
  exact required files/dependencies.

### Lane F: UX/a11y reviewer

Responsibilities:

- Review screenshots, keyboard traces, route states, and failure artifacts.
- Apply Nielsen heuristics, accessibility basics, and UI polish criteria.
- Separate critical blockers from important UX issues and suggestions.
- Convert vague impressions into specific findings with reproduction and fix
  direction.

Checklist:

- Visibility: Does the user know what is loading, failed, saved, or complete?
- Control: Can the user escape modals/tours and recover from mistakes?
- Consistency: Do cards, panels, nav, and CTAs describe the same state?
- Error help: Are errors specific and actionable?
- Keyboard: Is every control reachable, named, focus-visible, and logically ordered?
- Mobile: Are primary actions visible, tappable, and safe-area aware?
- Visual: Any clipping, overlap, weak contrast, cramped text, nested cards, or
  decorative noise?

## Swarm Sizes

Start smaller than you think.

### Small, 3 panes

- Pane 1: coordinator/bead writer.
- Pane 2: agent-browser exploratory driver.
- Pane 3: next-browser/runtime inspector plus Playwright runner.

Use when the app is unstable or the target scope is one feature.

### Medium, 5 panes

- Pane 1: coordinator/bead writer.
- Pane 2: agent-browser desktop workflow.
- Pane 3: agent-browser mobile/responsive workflow.
- Pane 4: next-browser inspector.
- Pane 5: Playwright/evidence runner plus UX reviewer.

Use when the app renders and you need broad route coverage.

### Large, 7 panes

- Pane 1: coordinator.
- Pane 2: auth/navigation/layout.
- Pane 3: core workflow happy path.
- Pane 4: error/empty/loading states.
- Pane 5: mobile/responsive.
- Pane 6: next-browser/runtime/network.
- Pane 7: React DevTools/performance or UX/a11y review.

Use only when the operator loop is healthy and the app has enough route surface
to avoid duplicate work.

## NTM Setup

Discover the local robot surface before relying on stale flags:

```bash
ntm --robot-capabilities
ntm --robot-docs=quickstart
ntm --robot-status
ntm --robot-snapshot
```

If you need a new session and repo policy allows it:

```bash
ntm spawn <project> --cod=3 --cc=1 --gmi=1
```

If a session already exists:

```bash
ntm status <project>
ntm add <project> --cod=1
```

Avoid `ntm dashboard`, `ntm palette`, and `ntm view` from agent automation.
Those are human TUI surfaces.

## Marching Orders

Send a role-specific prompt to each pane. Do not broadcast the same vague prompt.

### Coordinator prompt

```text
You are the browser QA coordinator for <repo>. Read AGENTS.md and the existing
E2E/browser-testing docs. Do not edit product code. Check br, bv, Agent Mail
reservations, and git status. Assign each browser-testing pane a unique route
or tool lane. Keep an avoid-list of claimed routes/findings. You are the only
pane allowed to create beads unless explicitly instructed otherwise. Every bead
must include route, tool, command, expected/actual behavior, evidence artifact,
severity, and verification steps. Use robot-mode NTM commands only.
```

### agent-browser driver prompt

```text
You own headed agent-browser exploratory testing for <route-or-flow>. First run
agent-browser skills get core. Use a unique session name and a short socket dir
such as AGENT_BROWSER_SOCKET_DIR=/tmp/ab. Log in with the repo's test user, then
drive the UI with real clicks, fills, hovers, scrolling, and keyboard navigation.
After every page-changing action, re-snapshot. Capture screenshots for visual
or UX issues. Report findings to the coordinator only; do not create beads.
```

### next-browser inspector prompt

```text
You own Next.js runtime inspection for <route-set>. Run from the Next.js app
directory. Open the route with next-browser, then collect errors, page segments,
network, logs, and component tree evidence. Treat build/runtime overlays as
blockers. For suspicious network entries, inspect request/response details.
Report route, command, exact error, source file/line, and likely owner. Do not
edit code or create beads unless reassigned.
```

### Playwright evidence prompt

```text
You own repeatable E2E evidence. Run the repo's existing Playwright smoke/demo
scripts against the already-running dev server. Use documented test users and
base URL. Preserve trace, screenshot, video, and error-context paths. If a spec
fails, classify whether the failure is a product bug, harness contract drift,
build blocker, auth setup problem, or environmental issue. Report only evidence
and classification to the coordinator.
```

### React DevTools prompt

```text
You own React DevTools inspection. Check agent-react-devtools status first. If
the app is not connected, run init --dry-run and report the exact files and
dependencies required; do not apply instrumentation unless assigned. If
connected, capture tree depth 3, inspect relevant components, profile one slow
or high-value interaction while another browser lane drives the UI, then report
slow components and rerender causes.
```

### UX/a11y reviewer prompt

```text
You own UX/a11y review. Inspect screenshots, keyboard traces, and browser
snapshots from the other lanes. Apply Nielsen heuristics, accessibility basics,
and premium UI polish criteria separately for desktop and mobile. Produce
prioritized findings: Critical, Important, Suggestions. Each finding needs a
specific route/state, why it hurts users, and a concrete fix direction. Do not
file duplicates; coordinate with the bead writer.
```

## Operator Tick

Every 5 to 15 minutes, the coordinator runs:

```bash
ntm --robot-is-working=<session>
ntm --robot-agent-health=<session>
ntm coordinator digest <session>
ntm coordinator conflicts <session>
ntm --robot-tail=<session> --lines=40
br list --status open,in_progress,claimed --json
bv --robot-triage
git status --short
```

Then classify:

- **Working**: leave alone.
- **Idle with no route assigned**: send one specific route/tool assignment.
- **Duplicate route**: redirect one pane.
- **Build blocker found**: pause visual polish lanes; route one pane to evidence
  and one to the fix if implementation is in scope.
- **Rate limited/stuck**: use `vibing-with-ntm` liveness truth stack and recovery
  ladder.
- **Converged**: stop nudging, collect findings, write beads, release locks.

Do not nudge every pane every tick. NTM swarms get worse when the coordinator
adds noise faster than agents can produce evidence.

## Evidence Contract

Every finding must include:

- **ID**: temporary unique finding id, or bead id after creation.
- **Severity**: P0/P1/P2/P3 or Critical/Important/Suggestion.
- **Route and state**: exact URL/path, viewport, auth state, feature flag state.
- **Tool**: agent-browser, next-browser, Playwright, React DevTools, manual
  screenshot review, or combination.
- **Command(s)**: exact commands or test name.
- **Expected**: what should happen.
- **Actual**: what happened.
- **Evidence**: screenshot path, trace path, video path, next-browser error JSON,
  network index, console log, component label, or keyboard trace.
- **Likely owner**: route/component/file if known.
- **Fix direction**: concrete enough for an implementing agent.
- **Verification**: how to prove it is fixed.

If a finding cannot meet this contract, keep it as a note, not a bead.

## Bead Writing Rules

Only the coordinator writes beads unless explicitly delegated.

Before bead mutation:

```bash
br sync --status --json
am robot reservations --project "$PWD" --format json
am file_reservations reserve "$PWD" <agent-name> '.beads/**' --ttl 1800 --exclusive --reason 'browser QA bead creation'
```

For each bead, include:

- Background with route and evidence.
- Scope and out-of-scope.
- Design notes for UX/visual work.
- Acceptance criteria with browser-verifiable outcomes.
- Verification notes with exact commands.
- Labels for route/tool/domain.
- Dependencies on build blockers or harness blockers when appropriate.

After mutation:

```bash
br sync --flush-only
br sync --status --json
br dep cycles
git status --short .beads
am file_reservations release "$PWD" <agent-name> '.beads/**'
```

Do not commit `.beads` unless the user requested a commit.

## Severity Rubric

- **P0**: App cannot build/render; data loss; auth/security break; browser QA is
  blocked by a compile/runtime overlay.
- **P1**: Core user workflow broken; test harness cannot reach a required
  product surface; record/save/publish path blocked.
- **P2**: Degraded UX, a11y, observability, or tooling that slows reliable QA but
  has a workaround.
- **P3**: Polish, docs, patch upgrades, convenience scripts, or adoption tasks.

Never inflate visual preferences to P0. Never downplay build overlays as polish.

## Common Failure Modes

### Browser daemon path too long

Symptom:

```text
Socket path would be ... bytes (max 103)
```

Fix:

```bash
export AGENT_BROWSER_SOCKET_DIR=/tmp/ab
agent-browser --session q --headed open http://localhost:3000/login
```

### next-browser cannot find Chromium

Symptom:

```text
Executable doesn't exist at ... ms-playwright/.../Google Chrome for Testing
```

Fix:

```bash
npx playwright install chromium
```

or, in isolated homes where the real cache already exists:

```bash
mkdir -p /tmp/nb/Library/Caches
ln -sfn /Users/<user>/Library/Caches/ms-playwright /tmp/nb/Library/Caches/ms-playwright
HOME=/tmp/nb NEXT_BROWSER_HOME=/tmp/nb next-browser open http://localhost:3000/login
```

### React DevTools not connected

Symptom:

```text
Daemon is not running
0 connected apps
```

Fix path:

```bash
agent-react-devtools init --dry-run
```

Report the required files and dependencies. Instrument only if assigned.

### Build overlay blocks QA

Symptom: next-browser errors or screenshots show a Next.js build/runtime overlay.

Action:

1. Capture `next-browser errors`.
2. Save screenshot or Playwright failure artifact.
3. Create/route a P0/P1 build bead.
4. Pause visual polishing until product UI renders.

### Auth redirects assets

Symptom: next-browser network shows static assets returning 307 to login.

Action:

1. Inspect `network <idx>`.
2. Check middleware/static asset exclusions.
3. Verify unauthenticated protected routes still redirect.

### Duplicate findings across panes

Symptom: multiple agents report the same route issue with slightly different words.

Action:

1. Coordinator dedupes by route/state/root cause.
2. Keep the strongest evidence artifact.
3. Credit supporting observations in notes.
4. Create one bead.

## Route Matrix Template

Use this during coordination:

```text
Route/Flow | Owner Pane | Tool | Viewport | Auth State | Status | Evidence
/login | pane 2 | agent-browser | 1440x900 | anonymous | done | screenshot path
/dashboard | pane 3 | next-browser | desktop | authenticated | blocker | errors JSON
/courses/:id/outline | pane 4 | Playwright | desktop/mobile | authenticated | running | trace path
/courses/:id/posts/:id/record | pane 5 | agent-browser | desktop | authenticated | blocked | overlay screenshot
```

## Finding Template

```markdown
### FINDING: <short title>
Severity: P1
Route/state: /courses/<id>/outline, 1440x900, authenticated
Tool: next-browser + Playwright
Commands:
- HOME=/tmp/nb NEXT_BROWSER_HOME=/tmp/nb next-browser errors
- npm run test:e2e:demo-qa
Expected:
The outline page renders the workflow rail and selected lesson editor.
Actual:
Next.js build overlay appears with syntax error in route.ts line 460.
Evidence:
- test-results/.../test-failed-1.png
- next-browser errors JSON
Likely owner:
ui/src/app/api/editor-states/route.ts
Fix direction:
Repair the malformed route handler tail and verify editor-state route compile.
Verification:
next-browser errors is empty on /dashboard and demo QA reaches record surface.
```

## Anti-Patterns

- Spawning seven browser agents before the app builds.
- Letting every pane create beads.
- Running `ntm dashboard` or `ntm view` from automation.
- Using the same browser session name in multiple panes.
- Forgetting to load `agent-browser skills get core`.
- Treating `page.evaluate()` success as user-flow success.
- Filing "bad UX" without screenshot, route, viewport, and fix direction.
- Continuing visual QA while a build overlay blocks product UI.
- Starting another dev server on a port that is already owned.
- Ignoring Agent Mail reservations because `br` looks clean.
- Closing the browser before saving screenshots/traces.
- Creating broad "polish everything" beads instead of route/state-specific work.

## Stop Conditions

Stop the swarm when any of these hold:

- A P0/P1 build blocker prevents meaningful browser QA.
- All assigned routes have evidence and no new findings appear for two ticks.
- `br ready` plus in-progress/claimed state shows no remaining QA work and panes
  are producing convergence language.
- The coordinator cannot keep up with duplicate findings.
- The user asked for planning/beads only and implementation would be a mode
  change.

When stopping, produce:

- Routes tested.
- Tools used.
- Findings created or updated.
- Evidence paths.
- What could not be tested and why.
- Suggested next bead order.
