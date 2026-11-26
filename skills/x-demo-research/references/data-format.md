# Research data format

The renderer takes one JSON object. All report text is plain text, escaped by the renderer. It performs no network requests. Keep source excerpts short; paraphrase by default. New opportunity runs use `schema_version: 2`. The older demo format remains renderable for existing reports.

Required fields:

- `topic`, `lead`, `access_mode`, `stop_reason`: strings. Access mode is `api`, `export`, `x-browser`, or `indexed-web`.
- `window`: object with `start` and `end` ISO timestamps including offsets, and `timezone` (IANA name). Start inclusive, end exclusive.
- `target`: positive integer, normally 1000.
- `limitations`: list of strings describing access, coverage, date or verification issues.
- `queries`: list of objects with strings `query`, `retrieved_at`, and `outcome`. Include excluded URLs/reasons and pagination status in outcome. One entry may represent a batched search if its outcome cannot be attributed to individual queries; list every exact query in its query string.
- `posts`: list of objects: `id` (numeric string), `url` (https X/Twitter status URL), `author`, `published_at` (ISO with offset), `text`, `verification` (`full`/`snippet`), `relevant` (boolean). Optional engagement is provenance only, never an eligibility filter. Conflicting duplicate records must be reconciled before rendering.
- `findings`: list of objects: `title`, `detail` (include confidence/counterevidence), `evidence_ids` (nonempty list of eligible post IDs).
- Version 1 `ideas`: list of objects: `title`, `audience`, `friction`, `demo`, `success`, `next_step` (strings), `status` (`supported`/`hypothesis`), `evidence_ids` (nonempty for supported; empty for hypothesis).

## Opportunity format (version 2)

Every post additionally requires `kind`: `firsthand-concern`, `firsthand-workaround`, `question`, `commentary`, `tool-claim`, or `irrelevant`. Retain original source URLs and short paraphrases; use optional `queries` for query IDs and `independence_group` for a shared incident/thread. `irrelevant` posts must have `relevant: false`. Additional provenance fields are preserved in JSON.

`opportunities` is an ordered list, possibly empty. Each requires:

- `rank`: consecutive positive integer starting at 1, matching list order.
- `title`, `audience`, `concern`, `impact`, `workaround`, `gap`, `intervention`, `next_step`, `buyer_signal`, `ranking_rationale`: plain strings. Label gap and intervention as inference/proposal, coverage unknown where needed, and buyer signal as none observed when appropriate.
- `confidence`: `low`, `medium`, or `high`; explain the limitations in ranking rationale.
- `evidence_ids`: nonempty eligible concern/workaround/question IDs. These are demand evidence, not vendor pitches. Author counts are derived from these IDs; shared incidents require additional qualitative qualification.
- `existing_tools`: list of objects with `name`, `coverage`, `remaining_gap`, `claim_type` (`claimed-on-x`, `user-reported`, or `unknown`), and `evidence_ids`. Non-unknown claims require eligible X-post evidence. Unknown claims must have empty evidence IDs and must not assert a missing capability.

`findings` may cite any eligible type, but titles and prose must distinguish demand from commentary/tool claims. No field imports evidence from non-X sources. Previous Reddit-backed recommendations must not be carried into a new ranking without qualifying X evidence.

An empty opportunity sample uses `posts: []`, `findings: []`, `opportunities: []`. Do not add invented posts or ranked hypotheses to make a live report look complete. Test fixtures belong in separate temporary test files.
