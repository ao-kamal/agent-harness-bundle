# Self-Test: browser-testing-with-ntm

## Verification
- [ ] `jsm validate /Users/darrenybarra/.agents/skills/browser-testing-with-ntm` passes.
- [ ] The description triggers on "parallel browser QA with NTM", "agent-browser and next-browser swarm", and "turn browser findings into beads".
- [ ] The skill tells agents to use robot-mode NTM surfaces instead of `ntm dashboard`, `ntm palette`, or `ntm view`.
- [ ] The skill assigns distinct lanes for coordinator, agent-browser, next-browser, Playwright, React DevTools, and UX/a11y review.
- [ ] The skill includes the evidence contract required before filing beads.
- [ ] The skill includes the `.beads/**` reservation and sync flow before tracker mutation.
- [ ] The skill includes headed mode and short socket/cache setup for browser tooling.
- [ ] The skill states that build overlays block visual QA and should become P0/P1 findings first.
- [ ] The skill does not require project-specific credentials; it uses examples that must be replaced by repo-local test users.

## Scenario Prompts

Use these to validate triggering and behavior:

1. "Use NTM to have several agents test my Next.js app with agent-browser, next-browser, Playwright, and React DevTools, then create beads for the findings."
2. "I want a browser QA swarm. One agent should inspect Next errors, another should click through the UI, and another should run E2E tests."
3. "Coordinate parallel UX/a11y testing and make sure only one agent writes beads."

Expected response:

- Loads this skill.
- Reads repo rules first.
- Checks dev server, tracker, and reservations.
- Assigns browser evidence lanes.
- Uses NTM robot-mode commands.
- Requires concrete evidence before bead creation.
