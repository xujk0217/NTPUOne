import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
import graduation_diagnostic as diagnostic
from academic_probe import ProbeError


class GraduationDiagnosticTests(unittest.TestCase):
    def test_credit_shapes_hide_values_and_handle_void_tags(self):
        parser = diagnostic.CreditShape()
        parser.feed('''<html><head><meta name=x></head><body><div id="tag_total"><div class="credit_box">
        <div class="main_credit">123<span class="unit_text">學分</span></div>
        <br><div class="total_credit">/128</div></div></div></body></html>''')
        self.assertEqual(len(parser.results), 1)
        self.assertEqual(parser.results[0]['section'], 'tag_total')
        self.assertEqual(parser.results[0]['main']['digit_lengths'], [3])
        self.assertEqual(parser.results[0]['total']['digit_lengths'], [3])
        self.assertTrue(parser.results[0]['total']['contains_separator'])
        self.assertNotIn('123', json.dumps(parser.results))
        self.assertNotIn('128', json.dumps(parser.results))

    def test_bridge_restricts_host_and_readonly_target(self):
        good = {'form_url': 'https://ohs01.ntpu.edu.tw/pls/pm/stud_system.signin',
                'base_url': 'https://ohs01.ntpu.edu.tw/pls/univer/query_all_course.judge?func=9_m',
                'formData': {'id': 'example', 'pw': 'example'}}
        self.assertEqual(diagnostic.validated_descriptor(json.dumps(good)), good)
        for changes in ({'form_url': 'https://ohs02.ntpu.edu.tw/pls/pm/stud_system.signin'},
                        {'base_url': 'https://ohs01.ntpu.edu.tw/pls/univer/query_all_course.judge?func=3_m'},
                        {'base_url': 'https://cof.ntpu.edu.tw/pls/univer/query_all_course.judge?func=9_m'}):
            with self.assertRaises(ProbeError):
                diagnostic.validated_descriptor(json.dumps(dict(good, **changes)))


if __name__ == '__main__':
    unittest.main()
