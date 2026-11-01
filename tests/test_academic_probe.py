"""Offline safety/contract checks; synthetic fixtures are NOT live integration evidence."""
import contextlib
import io
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import Mock, patch
import urllib.error

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import academic_probe as probe

SENTINEL = "PRIVATE_TEST_VALUE_DO_NOT_LOG"


class Response:
    status = 200
    def __init__(self, data): self.data = json.dumps(data).encode()
    def __enter__(self): return self
    def __exit__(self, *args): pass
    def read(self, _): return self.data


class AcademicProbeChecks(unittest.TestCase):
    def setUp(self):
        capture = patch("sys.stdout", new_callable=io.StringIO)
        capture.start()
        self.addCleanup(capture.stop)

    def client_response(self, result):
        client = probe.MoodleClient()
        client.opener = Mock()
        client.opener.open.return_value = Response(result)
        return client

    def catalog(self):
        return {"userid": 42, "username": SENTINEL, "functions": [
            {"name": name} for name in probe.READ_FUNCTIONS
        ]}

    def test_schema_masks_values_and_dynamic_keys(self):
        result = probe.shape({"fullname": SENTINEL, "grade": 99.42, SENTINEL: SENTINEL,
                              "lastattempt": {"submission": {"status": "submitted"}}})
        encoded = json.dumps(result)
        self.assertNotIn(SENTINEL, encoded)
        self.assertNotIn("99.42", encoded)
        self.assertEqual(result["lastattempt"]["submission"]["status"], "str")

    def test_token_only_in_post_body(self):
        client = self.client_response({"userid": 42})
        client.call("core_webservice_get_site_info", SENTINEL)
        request = client.opener.open.call_args[0][0]
        self.assertEqual(request.get_method(), "POST")
        self.assertNotIn(SENTINEL, request.full_url)
        self.assertIn(SENTINEL.encode(), request.data)
        self.assertNotIn("Cookie", request.headers)

    def test_unknown_remote_error_is_not_echoed(self):
        client = self.client_response({"errorcode": SENTINEL, "message": SENTINEL, "error": SENTINEL})
        with self.assertRaises(probe.ProbeError) as caught:
            client.call("core_webservice_get_site_info", SENTINEL)
        self.assertEqual(str(caught.exception), "remote_error")

    def test_http_200_invalid_token_is_failure(self):
        client = self.client_response({"errorcode": "invalidtoken", "message": SENTINEL})
        with self.assertRaises(probe.ProbeError) as caught:
            client.call("core_webservice_get_site_info", SENTINEL)
        self.assertEqual(caught.exception.code, "invalidtoken")

    def test_redirect_handler_does_not_forward_credentials(self):
        self.assertIsNone(probe.NoRedirect().redirect_request(None, None, 302, "", {}, "https://example.org/"))
        client = probe.MoodleClient()
        client.opener = Mock()
        client.opener.open.side_effect = urllib.error.HTTPError("https://example.org/", 302, SENTINEL, {}, None)
        with self.assertRaises(probe.ProbeError) as caught:
            client.call("core_webservice_get_site_info", SENTINEL)
        self.assertEqual(caught.exception.code, "redirect_blocked")
        self.assertNotIn(SENTINEL, str(caught.exception))

    def test_mutating_functions_rejected_before_network(self):
        client = probe.MoodleClient()
        client.opener = Mock()
        with self.assertRaises(probe.ProbeError):
            client.call("mod_assign_submit_for_grading", SENTINEL)
        client.opener.open.assert_not_called()

    def test_reserved_parameters_cannot_override_identity(self):
        client = probe.MoodleClient()
        with self.assertRaises(probe.ProbeError):
            client.call("core_webservice_get_site_info", SENTINEL, {"wstoken": "other"})

    def test_unknown_endpoints_are_rejected(self):
        with self.assertRaises(probe.ProbeError):
            probe.MoodleClient().request("https://example.org/upload")

    def test_login_requires_site_supported_mode(self):
        client, vault = Mock(), Mock()
        client.public_config.return_value = (200, {"enablewebservices": 1, "enablemobilewebservice": 1, "typeoflogin": 2})
        with patch.object(probe, "secret_input") as prompt:
            with self.assertRaises(probe.ProbeError) as caught:
                probe.login(client, vault, "test")
        self.assertEqual(caught.exception.code, "browser_login_required")
        prompt.assert_not_called()
        vault.operation.assert_not_called()

    def test_login_stores_only_verified_token_and_identity(self):
        client, vault = Mock(), Mock()
        client.public_config.return_value = (200, {"enablewebservices": 1, "enablemobilewebservice": 1, "typeoflogin": 1})
        client.request.return_value = (200, {"token": SENTINEL, "privatetoken": "unused-private-token"})
        client.call.return_value = (200, self.catalog())
        output = io.StringIO()
        with patch.object(probe, "secret_input", side_effect=["test-user", "test-password"]), contextlib.redirect_stdout(output):
            probe.login(client, vault, "test")
        payload = vault.operation.call_args[0][2]
        self.assertEqual(set(payload), {"token", "userid"})
        self.assertNotIn(SENTINEL, output.getvalue())
        self.assertNotIn("test-password", output.getvalue())
        self.assertNotIn("test-user", output.getvalue())

    def test_failed_identity_does_not_save_token(self):
        client, vault = Mock(), Mock()
        client.public_config.return_value = (200, {"enablewebservices": 1, "enablemobilewebservice": 1, "typeoflogin": 1})
        client.request.return_value = (200, {"token": SENTINEL})
        client.call.return_value = (200, {"userid": 0})
        with patch.object(probe, "secret_input", side_effect=["test-user", "test-password"]):
            with self.assertRaises(probe.ProbeError): probe.login(client, vault, "test")
        vault.operation.assert_not_called()

    def test_account_switch_stops_before_courses(self):
        client, vault = Mock(), Mock()
        vault.operation.return_value = {"token": SENTINEL, "userid": 43}
        client.call.return_value = (200, self.catalog())
        with self.assertRaises(probe.ProbeError) as caught: probe.verify(client, vault, "test")
        self.assertEqual(caught.exception.code, "account_identity_changed")
        self.assertEqual(client.call.call_count, 1)

    def test_unavailable_functions_are_not_assumed(self):
        client, vault = Mock(), Mock()
        vault.operation.return_value = {"token": SENTINEL, "userid": 42}
        client.call.return_value = (200, {"userid": 42, "functions": []})
        with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(probe.ProbeError) as caught:
            probe.verify(client, vault, "test")
        self.assertEqual(caught.exception.code, "required_read_functions_unavailable")

    def test_repeated_course_page_stops(self):
        client, vault = Mock(), Mock()
        vault.operation.return_value = {"token": SENTINEL, "userid": 42}
        client.call.side_effect = [(200, self.catalog()), (200, {"courses": [{"id": 1}], "nextoffset": 1}),
                                   (200, {"courses": [{"id": 1}], "nextoffset": 2})]
        with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(probe.ProbeError) as caught:
            probe.verify(client, vault, "test")
        self.assertEqual(caught.exception.code, "course_page_repeated")

    def test_draft_and_grade_do_not_imply_completion(self):
        observed = probe.submission_observation({"lastattempt": {"submission": {"status": "draft"}, "graded": True}})
        self.assertEqual(observed["individual_state"], "draft")
        self.assertFalse(observed["completion_inferred"])
        self.assertTrue(observed["graded"])

    def test_team_status_and_unknown_status_remain_separate(self):
        observed = probe.submission_observation({"lastattempt": {"submission": {"status": SENTINEL},
                                                               "teamsubmission": {"status": "submitted"}}})
        self.assertEqual(observed["individual_state"], "unknown")
        self.assertEqual(observed["team_state"], "submitted")
        self.assertFalse(observed["completion_inferred"])

    def test_missing_attempt_is_not_success(self):
        with self.assertRaises(probe.ProbeError): probe.submission_observation({})

    def test_non_interactive_secret_input_refused(self):
        with patch.object(sys.stdin, "isatty", return_value=False), patch.object(getattr(probe, "getpass"), "getpass") as prompt:
            with self.assertRaises(probe.ProbeError): probe.secret_input("Password:")
        prompt.assert_not_called()

    def test_term_hint_requires_multiple_fields(self):
        with patch.object(probe, "current_term", return_value=(115, 1)):
            self.assertTrue(probe.has_current_term_hint({"fullname": "1151 synthetic", "shortname": "115-1"}))
            self.assertFalse(probe.has_current_term_hint({"fullname": "1151 synthetic"}))
            self.assertFalse(probe.has_current_term_hint({"fullname": "1141", "shortname": "114-1"}))

    def test_limited_probe_checks_only_token_owner_and_does_not_claim_completion(self):
        client, vault = Mock(), Mock()
        vault.operation.return_value = {"token": SENTINEL, "userid": 42}
        client.call.side_effect = [
            (200, self.catalog()),
            (200, {"courses": [{"id": 1, "fullname": "1151 synthetic", "shortname": "115-1"}], "nextoffset": 1}),
            (200, {"courses": [], "nextoffset": 1}),
            (200, {"courses": [{"id": 1, "assignments": [{"id": 11}, {"id": 12}]}], "warnings": []}),
            (200, {"lastattempt": {"submission": {"status": "submitted"}, "graded": False}}),
        ]
        output = io.StringIO()
        with patch.object(probe, "current_term", return_value=(115, 1)), contextlib.redirect_stdout(output):
            probe.verify(client, vault, "test", max_courses=1, max_submissions=1)
        calls = client.call.call_args_list
        self.assertEqual(calls[-1].args, ("mod_assign_get_submission_status", SENTINEL, {"assignid": 11}))
        self.assertNotIn(SENTINEL, output.getvalue())
        summary = json.loads(output.getvalue().splitlines()[-1])
        self.assertFalse(summary["phase_1_complete"])
        self.assertEqual(summary["submission_responses"], 1)
        self.assertEqual(summary["assignment_count"], 2)


if __name__ == "__main__":
    unittest.main()
