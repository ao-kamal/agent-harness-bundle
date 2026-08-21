Use the `firecrawl developer` CLI (the Firecrawl Developer Index) to answer questions about how a library, framework, SDK, API, or cloud service actually behaves — API syntax and contracts, configuration options, version-specific behavior and breaking changes, library-specific debugging, setup instructions, whether a bug was fixed. Use it even for well-known stacks (React, Next.js, Prisma, Express, Tailwind, Django) when the answer should come from a primary source: the issue that reported the bug, the merged PR that fixed it, or the README/docs passage that states the contract. Prefer this over general web search for library behavior.

Do not use for: refactoring, writing scripts from scratch, debugging business logic without a library angle, code review, or general programming concepts — those are ordinary work.

## Command

```bash
firecrawl developer "<question>" --limit 10        # ranked results with matched passages
firecrawl developer "<query>" --json               # machine-readable
```

Each result carries an `id` whose prefix is the artifact kind: `issue:owner/repo#123`, `pull_request:`, `readme:`, `doc:`, or `web:`. Results include the matched passages in markdown — quote them and cite the `url` rather than paraphrasing into a claim.

## Match the query to the question type

- **Literal error message** → search the message plus the library name; strip volatile parts (paths, line numbers) if nothing matches.
- **Known bug** → search the bug's terms; trust a merged PR over the opening issue report — the PR is current behavior.
- **API contract / "what does X return"** → prefer `readme:`/`doc:` results; a blog post is not authoritative.
- **Version-specific behavior** → read the resolution/PR, never just the opening report.
- **Comparison, opinion, ecosystem survey** → that's a web question: `firecrawl search`, then `firecrawl scrape` what deserves a full read. Don't force it through the index.

## Rules of engagement

- Quote the passage, cite the URL — passages are the evidence.
- A merge supersedes a report; say which one you read.
- Scope last, not first: search wide, then narrow if hits are noisy.
- If the index has nothing (echo shows unindexed repo/source), go to the open web instead of retrying.
- Do not include sensitive information (API keys, passwords, credentials) in queries.
