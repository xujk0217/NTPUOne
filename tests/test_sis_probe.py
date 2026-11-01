"""Offline login-safety checks; not evidence of a real SIS login."""
import contextlib
import io
import json
from pathlib import Path
import sys
import unittest
import urllib.request

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import academic_probe
import sis_probe


class SISProbeChecks(unittest.TestCase):
    def test_fresh_form_values_not_in_summary(self):
        text = '<form action="/login" method="post"><input name="_token" value="SECRET_CSRF"><input name="username"><input name="password"></form>'
        page = sis_probe.parsed(text)
        self.assertEqual(page.forms[0]["fields"]["_token"], "SECRET_CSRF")
        output = io.StringIO()
        with contextlib.redirect_stdout(output): sis_probe.summary(200, sis_probe.ORIGIN + "/login", page)
        self.assertNotIn("SECRET_CSRF", output.getvalue())
        self.assertFalse(json.loads(output.getvalue())["session_evidence"])

    def test_http_200_or_logout_link_alone_is_not_login(self):
        login = sis_probe.parsed('<a href="/logout">Exit</a><form><input name="username"><input name="password"></form>')
        self.assertFalse(sis_probe.confirmed_session(sis_probe.ORIGIN + "/", login))
        self.assertFalse(sis_probe.confirmed_session(sis_probe.ORIGIN + "/", sis_probe.parsed("Welcome")))

    def test_authenticated_page_is_only_session_evidence(self):
        page = sis_probe.parsed('<form action="/logout" method="post"></form>')
        self.assertTrue(sis_probe.confirmed_session(sis_probe.ORIGIN + "/", page))
        output = io.StringIO()
        with contextlib.redirect_stdout(output): sis_probe.summary(200, sis_probe.ORIGIN + "/", page)
        self.assertFalse(json.loads(output.getvalue())["identity_verified"])
        self.assertFalse(json.loads(output.getvalue())["phase_2_complete"])

    def test_route_parameters_and_identifiers_not_logged(self):
        page = sis_probe.parsed('<a href="/grades/SECRET_STUDENT_ID?token=SECRET_TOKEN">Private Name</a>')
        output = io.StringIO()
        with contextlib.redirect_stdout(output): sis_probe.summary(200, sis_probe.ORIGIN + "/", page)
        for secret in ("SECRET_STUDENT_ID", "SECRET_TOKEN", "Private Name"):
            self.assertNotIn(secret, output.getvalue())
        self.assertIn("/grades/<segment>", output.getvalue())

    def test_cross_origin_insecure_and_action_redirects_blocked(self):
        handler = sis_probe.SchoolRedirect()
        for url in ("https://example.org/login", "http://my.ntpu.edu.tw/", "https://my.ntpu.edu.tw/logout"):
            with self.assertRaises(academic_probe.ProbeError):
                handler.redirect_request(urllib.request.Request(sis_probe.ORIGIN), None, 302, "", {}, url)
        with self.assertRaises(academic_probe.ProbeError):
            handler.redirect_request(urllib.request.Request(sis_probe.ORIGIN), None, 307, "", {}, sis_probe.ORIGIN)

    def test_unverified_endpoints_are_not_requested(self):
        with self.assertRaises(academic_probe.ProbeError): sis_probe.Session().request("/grades")

    def test_cookie_scope_cannot_be_other_school_service(self):
        with self.assertRaises(academic_probe.ProbeError):
            sis_probe.Session().restore({"cookies": [{"domain": ".ntpu.edu.tw"}]})


if __name__ == "__main__":
    unittest.main()
