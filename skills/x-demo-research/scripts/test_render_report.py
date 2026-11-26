"""Behavioral checks using synthetic posts; no live research evidence."""
import copy
import unittest

from render_report import render


class ReportTests(unittest.TestCase):
    def setUp(self):
        self.data = {
            'schema_version': 2, 'topic': 'Fixture', 'lead': '<script>unsafe</script>',
            'access_mode': 'x-browser', 'window': {'start': '2026-11-19T00:00:00+02:00',
                'end': '2026-11-26T00:00:00+02:00', 'timezone': 'Asia/Jerusalem'},
            'target': 1000, 'stop_reason': 'Fixture budget', 'limitations': [],
            'queries': [], 'findings': [], 'posts': [], 'opportunities': []}
        self.post = {'id': '123', 'url': 'https://x.com/test/status/123', 'author': '@test',
            'published_at': '2026-11-25T12:00:00+02:00', 'text': 'Synthetic concern',
            'verification': 'full', 'kind': 'firsthand-concern', 'relevant': True}
        self.opportunity = dict.fromkeys(('title', 'audience', 'concern', 'impact',
            'workaround', 'gap', 'intervention', 'next_step', 'buyer_signal', 'ranking_rationale'), 'Fixture')
        self.opportunity.update(rank=1, confidence='low', evidence_ids=['123'], existing_tools=[])

    def test_empty_corpus_has_no_ranking(self):
        self.assertIn('No opportunities qualify for ranking', render(self.data))

    def test_cross_domain_duplicates_count_once(self):
        self.data['posts'] = [self.post, dict(self.post, url='https://twitter.com/test/status/123')]
        self.assertIn('<strong>1</strong>Eligible unique posts', render(self.data))

    def test_window_end_is_exclusive(self):
        self.data['posts'] = [dict(self.post, published_at=self.data['window']['end'])]
        self.data['opportunities'] = [self.opportunity]
        with self.assertRaises(ValueError): render(self.data)

    def test_promotion_cannot_be_demand(self):
        self.data['posts'] = [dict(self.post, kind='tool-claim')]
        self.data['opportunities'] = [self.opportunity]
        with self.assertRaises(ValueError): render(self.data)

    def test_coverage_requires_eligible_x_evidence(self):
        self.data['posts'] = [self.post]
        self.opportunity['existing_tools'] = [{'name': 'Fixture', 'coverage': 'Claim',
            'remaining_gap': 'Unknown', 'claim_type': 'claimed-on-x', 'evidence_ids': ['999']}]
        self.data['opportunities'] = [self.opportunity]
        with self.assertRaises(ValueError): render(self.data)

    def test_html_is_escaped(self):
        html = render(self.data)
        self.assertNotIn('<script>', html)
        self.assertIn('&lt;script&gt;', html)

    def test_non_x_evidence_rejected(self):
        self.data['posts'] = [dict(self.post, url='https://reddit.com/test/status/123')]
        with self.assertRaises(ValueError): render(self.data)

    def test_supported_ranking_links_to_its_evidence(self):
        self.data['posts'] = [self.post]
        self.data['opportunities'] = [self.opportunity]
        html = render(self.data)
        self.assertIn('href="#post-123"', html)
        self.assertIn('id="post-123"', html)
        self.assertIn('1 distinct source author(s)', html)

    def test_conflicting_duplicates_rejected(self):
        self.data['posts'] = [self.post, dict(self.post, text='Conflicting text')]
        with self.assertRaises(ValueError): render(self.data)

    def test_missing_rank_rejected(self):
        self.data['posts'] = [self.post]
        self.data['opportunities'] = [dict(self.opportunity, rank=2)]
        with self.assertRaises(ValueError): render(self.data)

    def test_legacy_report_still_renders(self):
        legacy = copy.deepcopy(self.data)
        del legacy['schema_version']
        del legacy['opportunities']
        legacy['ideas'] = []
        self.assertIn('No eligible posts collected', render(legacy))


if __name__ == '__main__':
    unittest.main()
