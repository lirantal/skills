#!/usr/bin/env python3
"""Render an auditable X research report; Python standard library only."""
import argparse
from datetime import datetime
from html import escape
import json
from pathlib import Path
import re
from zoneinfo import ZoneInfo


def stamp(value):
    result = datetime.fromisoformat(value.replace('Z', '+00:00'))
    if result.utcoffset() is None:
        raise ValueError('Timestamps require a timezone offset')
    return result


def esc(value):
    return escape(str(value), quote=True)


def render(data):
    start, end = (stamp(data['window'][k]) for k in ('start', 'end'))
    ZoneInfo(data['window']['timezone'])
    if start >= end:
        raise ValueError('Window start must precede end')
    if type(data['target']) is not int or data['target'] <= 0:
        raise ValueError('Target must be a positive integer')
    version = data.get('schema_version', 1)
    if version not in (1, 2):
        raise ValueError('Unknown schema version')
    if data['access_mode'] not in ('api', 'export', 'x-browser', 'indexed-web'):
        raise ValueError('Unknown access mode')
    unique = {}
    for post in data['posts']:
        pid = post['id']
        if not isinstance(pid, str) or not re.fullmatch(r'[0-9]+', pid):
            raise ValueError('Post ID must be a numeric string')
        match = re.fullmatch(r'https://(?:www\.)?(?:x\.com|twitter\.com)/(?:[A-Za-z0-9_]+|i/web)/status/([0-9]+)(?:[/?#].*)?', post['url'])
        if not match or match[1] != pid:
            raise ValueError('Post URL and ID must agree')
        stamp(post['published_at'])
        if type(post['relevant']) is not bool or post['verification'] not in ('full', 'snippet'):
            raise ValueError('Invalid relevance or verification')
        if version == 2:
            kinds = ('firsthand-concern', 'firsthand-workaround', 'question', 'commentary', 'tool-claim', 'irrelevant')
            if post['kind'] not in kinds or (post['kind'] == 'irrelevant' and post['relevant']):
                raise ValueError('Invalid post classification')
        for key in ('author', 'text'):
            if not isinstance(post[key], str) or not post[key].strip():
                raise ValueError(f'Post requires {key}')
        normalized = dict(post, url=f'https://x.com/i/web/status/{pid}')
        if pid in unique and unique[pid] != normalized:
            raise ValueError('Conflicting duplicate post; reconcile records first')
        unique[pid] = normalized
    eligible = {pid: p for pid, p in unique.items()
                if p['relevant'] and start <= stamp(p['published_at']) < end}

    def citations(item, required):
        ids = item['evidence_ids']
        if not isinstance(ids, list) or (required and not ids):
            raise ValueError('Supported claims require evidence IDs')
        if any(pid not in eligible for pid in ids):
            raise ValueError('Evidence must reference eligible collected posts')
        return ' '.join(f'<a href="#post-{pid}">[{pid}]</a>' for pid in dict.fromkeys(ids))

    findings = []
    for item in data['findings']:
        refs = citations(item, True)
        findings.append(f'<article class="card"><h3>{esc(item["title"])}</h3><p>{esc(item["detail"])}</p><p>{refs}</p></article>')
    ideas = []
    for item in data.get('ideas', []):
        if item['status'] not in ('supported', 'hypothesis'):
            raise ValueError('Unknown idea status')
        refs = citations(item, item['status'] == 'supported')
        if item['status'] == 'hypothesis' and item['evidence_ids']:
            raise ValueError('Hypotheses must not imply supporting evidence')
        fields = [('audience', 'Audience'), ('friction', 'Friction'), ('demo', 'Demo sequence'),
                  ('success', 'Observable success'), ('next_step', 'Next validation')]
        body = ''.join(f'<dt>{label}</dt><dd>{esc(item[key])}</dd>' for key, label in fields)
        label = 'Unvalidated hypothesis' if item['status'] == 'hypothesis' else 'Supported by collected posts'
        ideas.append(f'<article class="card"><p class="eyebrow">{label}</p><h3>{esc(item["title"])}</h3><dl>{body}</dl><p>{refs}</p></article>')
    opportunities = []
    for rank, item in enumerate(data.get('opportunities', []), 1):
        if version != 2 or type(item['rank']) is not int or item['rank'] != rank:
            raise ValueError('Opportunity ranks must be consecutive and ordered')
        if item['confidence'] not in ('low', 'medium', 'high'):
            raise ValueError('Invalid confidence')
        refs = citations(item, True)
        demand_kinds = ('firsthand-concern', 'firsthand-workaround', 'question')
        if any(eligible[pid]['kind'] not in demand_kinds for pid in item['evidence_ids']):
            raise ValueError('Opportunity demand cannot be established by commentary or tool promotion')
        authors = {eligible[pid]['author'].strip().lower().lstrip('@') for pid in item['evidence_ids']}
        tools = []
        for tool in item['existing_tools']:
            claim = tool['claim_type']
            if claim not in ('claimed-on-x', 'user-reported', 'unknown'):
                raise ValueError('Invalid tool claim type')
            tool_refs = citations(tool, claim != 'unknown')
            if claim == 'unknown' and tool['evidence_ids']:
                raise ValueError('Unknown coverage must not imply evidence')
            tools.append(f'<li><strong>{esc(tool["name"])}</strong> ({esc(claim)}): {esc(tool["coverage"])}<br>Gap assessment: {esc(tool["remaining_gap"])} {tool_refs}</li>')
        fields = [('audience', 'Persona'), ('concern', 'Stated concern'), ('impact', 'Consequence'),
                  ('workaround', 'Current workaround'), ('gap', 'Opportunity gap — inference'),
                  ('intervention', 'Smallest useful intervention — proposal'), ('buyer_signal', 'Buying signal'),
                  ('ranking_rationale', 'Why this rank and confidence'), ('next_step', 'Next validation')]
        body = ''.join(f'<dt>{label}</dt><dd>{esc(item[key])}</dd>' for key, label in fields)
        opportunities.append(f'<article class="card"><p class="eyebrow">Rank {rank} · {esc(item["confidence"])} confidence · provisional</p><h3>{esc(item["title"])}</h3><p>{len(authors)} distinct source author(s); shared incidents may reduce independence.</p><p>Demand evidence: {refs}</p><dl>{body}</dl><h4>Existing-tool coverage reported on X</h4><ul>{"".join(tools) or "<li>No qualifying tool-coverage posts collected; coverage remains unknown.</li>"}</ul></article>')
    if version == 2 and 'opportunities' not in data:
        raise ValueError('Version 2 requires an opportunities array')
    queries = ''.join(f'<li><pre>{esc(q["query"])}</pre><p>{esc(q["outcome"])}</p><small>Retrieved {esc(q["retrieved_at"])}</small></li>' for q in data['queries'])
    sources = ''.join(f'<article class="card" id="post-{pid}"><h3><a href="{p["url"]}">{esc(p["author"])} · {pid}</a></h3><small>{esc(p["published_at"])} · {esc(p["verification"])} · {esc(p.get("kind", "unclassified"))}</small><p>{esc(p["text"])}</p></article>' for pid, p in eligible.items())
    limitations = list(data['limitations'])
    if data['access_mode'] == 'indexed-web':
        limitations.append('Search-index coverage is selective. This sample cannot establish prevalence across X.')
    if len(eligible) < data['target']:
        limitations.append(f'Best-effort target missed: {len(eligible):,} of {data["target"]:,} eligible posts. {data["stop_reason"]}')
    warnings = ''.join(f'<li>{esc(s)}</li>' for s in limitations)
    css = (Path(__file__).resolve().parent.parent / 'assets/report.css').read_text()
    opportunity_section = '<section><h2>Ranked opportunities</h2>' + (''.join(opportunities) or '<p>No opportunities qualify for ranking from this collection.</p>') + '</section>' if version == 2 else ''
    demo_section = '<section><h2>Demo ideas</h2>' + ''.join(ideas) + '</section>' if ideas else ''
    return f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'">
<title>{esc(data['topic'])} — X research</title><style>{css}</style></head>
<body><main><header><p class="eyebrow">AI builder security · X research</p><h1>{esc(data['topic'])}</h1><p class="lead">{esc(data['lead'])}</p>
<p class="muted">{esc(data['window']['start'])} inclusive → {esc(data['window']['end'])} exclusive · {esc(data['window']['timezone'])}</p></header>
<section class="metrics" aria-label="Coverage"><p><strong>{len(eligible):,}</strong>Eligible unique posts</p><p><strong>{data['target']:,}</strong>Best-effort target</p><p><strong>{esc(data['access_mode'])}</strong>Collection mode</p></section>
<aside class="warning"><h2>Coverage and limitations</h2><ul>{warnings}</ul><p>Received {len(data['posts']):,} post records; {len(unique):,} unique IDs; {len(unique)-len(eligible):,} unique posts excluded by date or relevance. Non-post search results are excluded from these counts.</p></aside>
{opportunity_section}
<section><h2>Observed findings</h2>{''.join(findings) or '<p>No supported findings from this collection. This does not show an absence of discussion on X.</p>'}</section>
{demo_section}
<section><h2>Evidence corpus</h2>{sources or '<p>No eligible posts collected.</p>'}</section>
<section><h2>Collection log</h2><details><summary>{len(data['queries'])} logged search batches or requests</summary><ol>{queries}</ol></details><p>Stopped: {esc(data['stop_reason'])}</p></section>
<footer>Counts cover the collected corpus only. Supporting JSON accompanies this standalone report. No engagement threshold was applied.</footer></main></body></html>'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    try:
        output = render(json.loads(args.input.read_text()))
    except (ValueError, KeyError, TypeError) as error:
        parser.error(str(error))
    args.output.write_text(output)
    print(f'Rendered {args.output}')


if __name__ == '__main__':
    main()
