---
name: writing-style-explainer
description: >
  Write or revise evidence-driven technical articles and explainers, especially for
  JavaScript, Node.js, and security topics. Balances readable prose, mechanisms,
  runnable examples, and verification for lirantal.com, nodejs-security.com, or an
  editorial brief. Does not handle site publishing or asset generation.
metadata:
  author: lirantal
  version: 2.0.0
---

# Technical explainers people want to read

Read the [writing profile](assets/writing-style.json) before drafting or revising.
It defines shared editorial guidance, technical review, and destination overrides.
User instructions and the publication's supplied brief or repository conventions
take precedence over these defaults.

## Choose the argument before the outline

Identify the question the article answers and what the reader should understand or
be able to decide afterward. Default to experienced JavaScript and Node.js engineers;
adjust assumed knowledge to the brief without opening with an audience inventory.

Lead with a concrete problem, finding, or thesis and its consequence. Add background
only when it helps the reader follow the mechanism or argument. An explanation may
include a short reproduction or remediation procedure when keeping them together
helps the reader. A runnable example supports the explanation; it need not turn the
whole article into a tutorial.

Choose sections from the questions the reader needs answered. Length follows the
subject and brief. There are no word-count, sentence-count, paragraph-length, link,
FAQ, or CTA quotas. The profile's possible progression is an example, not a required
outline. A table, diagram, FAQ, table of contents, or separate conclusion earns its
place by helping the reader, rather than satisfying a template.

## Write with clarity and a point of view

Use concrete subjects, active verbs, and familiar words. Name the actual API, symbol,
flag, file, or behavior. Keep terminology consistent, and explain unfamiliar terms
when they first matter. Cut filler, inflated significance, vague attribution, and
stock transitions. Do not remove necessary technical terms merely because they
also appear on lists of overused words.

Vary sentence and paragraph lengths. Split sentences that require rereading, but
keep a longer sentence when its condition or consequence belongs with the claim.
Prefer active voice when the actor matters. Use sentence-case headings that help
the reader follow the argument, unless the destination requires another style.

Make recommendations with reasons and boundaries. Allow useful analogy, restrained
humor, and first-person experience when appropriate to the author and publication.
Never invent an anecdote, quote, experiment, or personal opinion on the author's
behalf. Avoid decorative flourishes and rhetorical formulas that add no information.
When a style rule harms precision or natural prose, rewrite another way or keep
the clearer sentence.

## Verify substance, then edit prose

First review the technical claims using the profile's evidence and verification
guidance. Explain the mechanism, provide representative examples where useful, and
cover alternatives and limitations that affect the recommendation. Link claims to
primary sources where they occur. A proposed experiment is not evidence of a result.

For security articles, distinguish attacker control, prerequisites, vulnerable
behavior, impact, mitigation, and residual risk wherever relevant. Verify affected
versions and fixes against authoritative sources. Label examples as illustrative
or pseudocode when they are not runnable.

Then edit for flow, repetition, ambiguity, and unnecessary sections without silently
changing technical meaning. If a statement remains unverified, qualify or remove it,
or explicitly report the verification gap. Never claim to have executed commands
or observed output without doing so.

## Fit the author and destination

If the user supplies or selects articles as voice references, read them and use
their openings, pacing, explanations, and degree of opinion to calibrate the draft.
Use references as evidence of style, not as a source of reusable sentences. Without
references, proceed with these defaults; do not claim they are measured features of
the author's writing or block work waiting for a corpus.

Apply the relevant destination guidance from the profile. Keep cover imagery and
its production out of article prose. Site files, frontmatter, assets, and build
checks belong to the destination's publishing workflow. This skill requires no
companion prose-cleanup skill.
