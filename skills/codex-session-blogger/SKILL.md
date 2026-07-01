---
name: codex-session-blogger
description: Turn a completed or in-progress Codex chat session, repository change, debugging investigation, implementation, code review, or security fix into a publishable technical blog draft. Use when the user asks to capture highlights from Codex work, write a post from a session, summarize agentic development lessons, draft for lirantal.com/blog, draft for nodejs-security.com/blog, or transform implementation/debugging/review findings into an article for agentic developers and software developers.
---

# Codex Session Blogger

## Overview

Use this skill to transform Codex session work into a technical article with a clear thesis, practical details, and reader value beyond a changelog.

Use `/Users/lirantal/.agents/skills/writing-style-explainer/SKILL.md` as the baseline writing style. If available, read its referenced `assets/writing-style.json` before drafting and apply its guidance on explainer structure, inline links, evidence, validation, trade-offs, FAQ depth, and no terminal references section.

## Workflow

1. Reconstruct the session outcome.
   - Identify the original goal, constraints, major decisions, files changed, commands run, tests or checks performed, failures encountered, and the final result.
   - Prefer evidence from the conversation, local diffs, test output, commit history, issue/PR context, and source files over memory.
   - Ask the user only when a missing fact would change the article's claim, publish target, or disclosure risk.

2. Choose the publish target.
   - Use `nodejs-security.com/blog` when the session is primarily about Node.js security, web security, dependency or supply-chain security, npm/pnpm package risk, secure CI/CD, vulnerability research, permission models, sandboxing, exploitability, or defensive patterns for JavaScript systems.
   - Use `lirantal.com/blog` for agentic development, Codex workflows, developer tooling, architecture, debugging stories, general JavaScript/Node.js engineering, open source maintenance, productivity, or broader software engineering lessons.
   - If both apply, prefer `nodejs-security.com/blog` only when the security lesson is the main reader payoff.

3. Extract the article angle.
   - Convert the session from “what changed” into “what readers can learn or apply.”
   - Look for: a surprising failure mode, a trade-off, a useful debugging path, a reproducible workflow, a security implication, a design decision, a validation technique, or a reusable agentic development pattern.
   - Avoid writing a diary of the session. The work session is raw material; the post should stand on its own for readers who were not present.

4. Build the article brief before drafting.
   - Publish target and rationale.
   - Working title, slug, one-sentence thesis, and 2-3 sentence abstract.
   - Primary audience and reader promise, phrased as editorial guidance rather than an opening paragraph.
   - Source material used: session notes, diffs, commands, docs, issues, PRs, or external references.
   - Disclosure boundaries: anything private, speculative, sensitive, or not yet publishable.

5. Draft in the explainer style.
   - Lead with the thesis, the problem, and why it matters now.
   - Show enough implementation detail for an experienced developer to trust the lesson.
   - Include mechanisms, trade-offs, validation steps, and concrete examples.
   - Use descriptive inline links to canonical docs, specifications, repos, or prior posts where each topic is introduced.
   - Do not add a terminal `## References`, bibliography, or link dump.

6. Close with practical next steps.
   - Prefer 3-5 concrete actions readers can take in their own projects.
   - Include GitHub and X/Twitter CTAs when they fit the article naturally.
   - For security posts, include detection, mitigation, or verification steps before broad calls to action.

## Session Mining Checklist

Gather these facts when they exist:

- Problem: what was broken, unclear, risky, slow, or worth improving.
- Constraint: what made the work non-trivial.
- Decision: which approach won and which alternatives were rejected.
- Mechanism: how the solution works internally.
- Evidence: tests, commands, screenshots, benchmark numbers, reproduction steps, or source links.
- Failure: an error, false start, misleading clue, or edge case that teaches something.
- Generalization: what transfers to other projects or teams.
- Boundary: what remains unknown, not covered, or not safe to claim.

## Article Shapes

Choose the shape that matches the session:

- **Explainer from implementation**: use when a concrete code change reveals a broader concept. Structure: thesis, background, mechanism, implementation details, trade-offs, validation, limitations, FAQ, next steps.
- **Debugging narrative**: use when the interesting part is diagnosis. Structure: symptom, failed hypotheses, turning point, root cause, fix, verification, what to monitor next time.
- **Agentic workflow post**: use when the lesson is about working with Codex or agents. Structure: task framing, context gathering, decision points, agent/human handoffs, verification, reusable workflow.
- **Security write-up**: use when the work involves exploitability, hardening, dependency risk, CI/CD risk, or secure defaults. Structure: threat model, vulnerable pattern, mechanism, safe reproduction, mitigation, detection, trade-offs, next steps.
- **Tooling or DX guide**: use when the work improves developer workflows. Structure: pain point, design goals, workflow, implementation, adoption path, edge cases, validation.

## Editorial Rules

- Make the reader payoff explicit early: what a developer can understand, avoid, build, or measure after reading.
- Preserve technical specificity. Include filenames, APIs, commands, config snippets, error messages, and version constraints when they matter.
- Do not publish private absolute paths, secrets, tokens, unpublished vulnerabilities, private customer details, internal URLs, or repository details the user did not make public.
- Replace session-local phrasing like “we did this earlier” with article-native context.
- Keep uncertainty visible. Use “in this implementation,” “for this repository,” or “under these constraints” when the claim is not universal.
- Prefer compact, runnable examples over long code dumps.
- Include validation commands with expected output or interpretation when possible.
- Avoid hype about agents. Show where Codex helped, where human judgment mattered, and how the result was verified.

## Output Contract

Unless the user asks for a different format, produce:

1. **Article Brief** with publish target, title, slug, thesis, abstract, tags, and disclosure notes.
2. **Draft** in Markdown suitable for the chosen blog.
3. **Inline Link Checklist** listing at least three planned or included canonical inline links, without creating a references section in the draft.
4. **Verification Notes** summarizing which claims came from session evidence and which still need confirmation.

If the user asks for only highlights, produce the brief and a structured outline instead of a full draft.
