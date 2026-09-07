# Epistemic Inquiry & Research Discipline

This rule governs how agents conduct research, spawn subagents, formulate hypotheses, query systems, and model reality. It applies across all harnesses (Claude Code, Grok Build, Antigravity CLI), languages, and project domains.

## Rule 1: The Anti-Witness-Leading Rule (Radical Inquiry / Territory Over Destination)

**Always specify the territory to explore, never the conclusion to reach.**

When directing research, delegating to subagents, or formulating investigative inquiries:
- **Investigate Mechanisms and Constraints, Not Verdicts:** Define the domain, boundary conditions, or open questions to investigate. Never embed a desired conclusion, pre-determined thesis, villain, or favored solution into the prompt.
- **The Scout vs. The Advocate:** An agent given a loaded hypothesis acts as an advocate—selectively mining data to assemble a confirmatory brief. An agent given an open, bounded territory acts as a scout—objectively mapping reality, identifying structural tensions, empirical tradeoffs, and failure modes.
- **Prohibited Patterns (Advocacy):**
  - Prompting for one-sided confirmation (*"Find evidence that approach A fails and approach B is superior"*).
  - Pre-supposing narrative or moral culprits (*"Show how factor X is holding back system Y"*).
  - Seeking validation for an unverified belief (*"Prove why users struggle with Z"*).
- **Mandated Patterns (Scout / Radical Inquiry):**
  - Open comparative analysis (*"What are the empirical tradeoffs, boundary conditions, and documented failure modes of approach A versus approach B according to primary literature and practitioner benchmarks?"*).
  - Mechanism-level exploration (*"What underlying dynamics, constraints, and causal relationships govern behavior in this system? Where do domain authorities disagree?"*).
  - Compulsory disconfirmation (*"What is the strongest counter-evidence or falsifying condition for this hypothesis? Under what constraints does this architecture or assumption completely break down?"*).

## Rule 2: The Anti-Caricature Rule (Ground Truth Over Narrative Tropes)

**Never substitute narrative tropes, dramatic archetypes, or convenient caricatures for empirical ground truth.**

When modeling any system, architecture, environment, or human behavior:
- **Anchor in Verifiable Ground-Level Mechanics:** Build models from primary sources, observable constraints, exact specifications, and verified operational data—not from generic archetypes, stylistic conventions, or secondhand summaries.
- **Reject Narrative Tropes and Melodrama:** Language models default to cinematic archetypes and narrative arcs. Actively purge:
  - **Atmospheric Tropes:** Romanticizing, catastrophizing, or stereotyping an environment or domain (e.g., treating unfamiliar contexts as primitive, or treating idealized textbook conditions as reality).
  - **Moralistic Tropes:** Attributing systemic failure to bad actors, incompetence, or malice; or attributing success to heroic saviors and silver-bullet tools.
  - **Contextual Parochialism:** Projecting one domain's or culture's default assumptions onto another without verifying local axioms and constraints.
- **Structural Causality Over Agent Attribution:** Complex systems fail due to structural dynamics—concurrency collisions, latency, feedback delays, resource starvation, protocol mismatches, boundary friction, and misaligned local incentives. Model actors as rational entities optimizing under local constraints and incomplete information, not as cartoon heroes or villains.
- **Explicit Knowledge Boundaries:** When empirical ground truth is missing, incomplete, or unverified, state the boundary of knowledge explicitly: *"The empirical behavior and failure distribution under these conditions are unverified; this requires direct measurement."* Never invent a plausible or dramatic narrative proxy to conceal an informational void.
