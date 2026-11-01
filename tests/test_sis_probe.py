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
    def menu(self, **changes):
        item = dict(page_name="選課清單", project_id=10, url=sis_probe.COURSE_LIST)
        item.update(changes)
        return item

    def test_dynamic_menu_is_json_not_executable_javascript(self):
        item = self.menu()
        text = "<script>var arr = " + json.dumps([item]) + ";</script>"
        self.assertEqual(sis_probe.verified_course_menu(text), item)
        for text in ("var arr = [danger()];", "var arr = [];", "var arr = {};"):
            with self.assertRaises(academic_probe.ProbeError): sis_probe.verified_course_menu(text)

    def test_course_menu_requires_exact_readonly_entry(self):
        for changes in (dict(page_name="選課系統"), dict(project_id=1), dict(url="https://example.org/")):
            with self.assertRaises(academic_probe.ProbeError):
                sis_probe.verified_course_menu("var arr = " + json.dumps([self.menu(**changes)]) + ";")
        with self.assertRaises(academic_probe.ProbeError):
            sis_probe.verified_course_menu("var arr = " + json.dumps([self.menu(), self.menu()]) + ";")

    def test_bridge_descriptor_requires_exact_destination_and_fields(self):
        good = dict(form_url=sis_probe.BRIDGE_LOGIN, base_url=sis_probe.BRIDGE_COURSE_LIST,
                    formData=dict(id="SYNTHETIC_ID", pw="SYNTHETIC_PASSWORD"))
        self.assertEqual(sis_probe.bridge_descriptor(json.dumps(good)), good)
        for changes in (dict(form_url="https://example.org/login"),
                        dict(base_url=sis_probe.BRIDGE_COURSE_LIST + "&func=99"),
                        dict(formData=dict(id="x", pw="y", extra="z"))):
            with self.assertRaises(academic_probe.ProbeError):
                sis_probe.bridge_descriptor(json.dumps(dict(good, **changes)))

    def test_bridge_does_not_follow_redirects_with_credentials(self):
        with self.assertRaises(academic_probe.ProbeError):
            sis_probe.BridgeNoRedirect().redirect_request(None, None, 302, "", {},
                                                        "https://example.org/")

    def test_course_page_keeps_script_data_out_of_table_cells(self):
        page = sis_probe.CoursePage()
        page.feed('<table><tr><th>科目名稱</th></tr><tr><td>Synthetic Course<script>SECRET_SCRIPT</script></td></tr></table>')
        self.assertEqual(page.rows, [["科目名稱"], ["Synthetic Course"]])
        self.assertNotIn("SECRET_SCRIPT", " ".join(page.text))

    def test_navigation_never_forwards_or_logs_credentials(self):
        calls = []
        class Client:
            def request(self, path):
                calls.append(path)
                return 200, sis_probe.ORIGIN, json.dumps(dict(form_url=sis_probe.BRIDGE_LOGIN,
                    base_url=sis_probe.BRIDGE_COURSE_LIST,
                    formData=dict(id="SECRET_ID", pw="SECRET_PASSWORD")))
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            sis_probe.navigation_observation(Client(), "var arr = " + json.dumps([self.menu()]) + ";")
        self.assertEqual(calls, [sis_probe.PROJECT_PATH])
        self.assertNotIn("SECRET", output.getvalue())
        self.assertFalse(json.loads(output.getvalue())["bridge_credentials_forwarded"])

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
