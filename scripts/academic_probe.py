#!/usr/bin/env python3
"""Local, read-only academic API verification. Never prints raw responses or secrets."""
from __future__ import annotations

import argparse
from datetime import datetime, timedelta, timezone
import getpass
import hashlib
import json
import re
from pathlib import Path
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import warnings

MOODLE = "https://lms3.ntpu.edu.tw"
READ_FUNCTIONS = frozenset({
    "core_webservice_get_site_info",
    "core_course_get_enrolled_courses_by_timeline_classification",
    "mod_assign_get_assignments", "mod_assign_get_submission_status",
    "core_calendar_get_action_events_by_timesort",
})
ERROR_CODES = frozenset({
    "invalidlogin", "invalidtoken", "missingparam", "invalidparameter",
    "accessexception", "webserviceaccess", "servicenotavailable",
    "enablewsdescription", "requireloginerror", "cannotcreatetoken",
    "usernotfullysetup", "usernotconfirmed", "maintenance",
})
SHAPE_KEYS = frozenset("""
userid username fullname firstname lastname sitename siteurl siteid functions name version
courses nextoffset id shortname idnumber categoryid startdate enddate visible summary viewurl
fullnamedisplay coursecategory courseimage isfavourite hidden hasprogress progress
courseid assignments assignmentid cmid duedate allowsubmissionsfromdate cutoffdate
intro introformat nosubmissions teamsubmission requireallteammemberssubmit submissiondrafts
warnings item itemid warningcode message lastattempt submission teamsubmission status
attemptnumber submittedforgrading graded feedback grade gradefordisplay gradelocked
gradingstatus canedit cansubmit submissionstatement showviewlink lastmodified timemodified
plugins type editorfields fileareas files filename filepath filesize fileurl mimetype
events instance activityname component modulename overdue timestart timeduration action
""".split())


class ProbeError(Exception):
    """Only fixed diagnostic codes may be exposed to the terminal."""
    def __init__(self, code, status=None):
        self.code, self.status = code, status
        super().__init__(code)


def emit(event, **fields):
    print(json.dumps(dict(event=event, **fields), ensure_ascii=False), flush=True)


def shape(value, depth=0):
    if depth >= 5:
        return type(value).__name__
    if isinstance(value, dict):
        # Unknown dynamic keys could themselves contain personal information.
        known = {k: shape(v, depth + 1) for k, v in value.items() if k in SHAPE_KEYS}
        other = sum(k not in SHAPE_KEYS for k in value)
        if other:
            known["other_field_count"] = other
        return known
    if isinstance(value, list):
        return {"count": len(value), "first_item_shape": shape(value[0], depth + 1) if value else None}
    return "null" if value is None else type(value).__name__


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class MoodleClient:
    def __init__(self):
        # No persistent cookie jar, automatic redirects, or implicit proxy configuration.
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())

    def request(self, path, fields=None, json_body=None):
        if path not in ("/login/token.php", "/webservice/rest/server.php",
                        "/lib/ajax/service.php?info=tool_mobile_get_public_config"):
            raise ProbeError("endpoint_not_allowed")
        if json_body is not None:
            data, content_type = json.dumps(json_body).encode(), "application/json"
        else:
            data = urllib.parse.urlencode(fields or {}).encode()
            content_type = "application/x-www-form-urlencoded"
        req = urllib.request.Request(MOODLE + path, data=data, method="POST", headers={
            "Content-Type": content_type, "User-Agent": "NTPUOne-Local-Academic-Probe/0.1",
        })
        try:
            with self.opener.open(req, timeout=25) as response:
                status = response.status
                data = response.read(8 * 1024 * 1024 + 1)
        except urllib.error.HTTPError as error:
            raise ProbeError("redirect_blocked" if 300 <= error.code < 400 else "http_error", error.code) from None
        except (urllib.error.URLError, TimeoutError, OSError):
            raise ProbeError("network_or_tls_error") from None
        if len(data) > 8 * 1024 * 1024:
            raise ProbeError("response_too_large", status)
        emit("http_response", endpoint=path.split("?", 1)[0], http_status=status)
        try:
            result = json.loads(data)
        except (ValueError, UnicodeError):
            raise ProbeError("non_json_response", status) from None
        if isinstance(result, dict) and any(k in result for k in ("error", "exception", "errorcode")):
            code = result.get("errorcode")
            raise ProbeError(code if isinstance(code, str) and code in ERROR_CODES else "remote_error", status)
        return status, result

    def public_config(self):
        status, result = self.request("/lib/ajax/service.php?info=tool_mobile_get_public_config", json_body=[
            {"index": 0, "methodname": "tool_mobile_get_public_config", "args": {}}
        ])
        if not isinstance(result, list) or len(result) != 1 or result[0].get("error") is not False:
            raise ProbeError("public_config_unavailable", status)
        config = result[0].get("data")
        if not isinstance(config, dict):
            raise ProbeError("unexpected_public_config", status)
        return status, config

    def call(self, function, token, params=None):
        if function not in READ_FUNCTIONS:
            raise ProbeError("function_not_allowed")
        fields = dict(params or {})
        if set(fields) & {"wstoken", "wsfunction", "moodlewsrestformat"}:
            raise ProbeError("reserved_parameter")
        fields.update(wstoken=token, wsfunction=function, moodlewsrestformat="json")
        return self.request("/webservice/rest/server.php", fields=fields)


def public_probe(client):
    status, config = client.public_config()
    emit("moodle_public_config", http_status=status,
         webservices_enabled=config.get("enablewebservices") == 1,
         mobile_enabled=config.get("enablemobilewebservice") == 1,
         login_type=config.get("typeoflogin"), authenticated=False)
    for label, path, fields in (
        ("token_without_credentials", "/login/token.php", {"service": "moodle_mobile_app"}),
        ("site_info_without_token", "/webservice/rest/server.php",
         {"wsfunction": "core_webservice_get_site_info", "moodlewsrestformat": "json"}),
    ):
        try:
            status, _ = client.request(path, fields=fields)
            emit(label, http_status=status, outcome="unexpected_response_not_authentication_success")
        except ProbeError as error:
            emit(label, http_status=error.status, diagnostic=error.code, authenticated=False)


def secret_input(prompt):
    if not sys.stdin.isatty():
        raise ProbeError("interactive_terminal_required")
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", getpass.GetPassWarning)
            result = getpass.getpass(prompt)
    except getpass.GetPassWarning:
        raise ProbeError("hidden_input_unavailable") from None
    if not result:
        raise ProbeError("empty_credential")
    return result


class Keychain:
    """Swift helper communicates secrets only through captured pipes, never argv or files."""
    def __enter__(self):
        if sys.platform != "darwin":
            raise ProbeError("macos_keychain_required")
        self.temp = tempfile.TemporaryDirectory(prefix="ntpuone-probe-")
        self.binary = Path(self.temp.name) / "AcademicProbeKeychain"
        source = Path(__file__).with_name("AcademicProbeKeychain.swift")
        try:
            subprocess.run(["xcrun", "swiftc", "-module-cache-path", str(Path(self.temp.name) / "cache"),
                            str(source), "-o", str(self.binary)], check=True, capture_output=True)
        except (OSError, subprocess.CalledProcessError):
            self.temp.cleanup()
            raise ProbeError("keychain_helper_build_failed") from None
        return self

    def __exit__(self, *args):
        self.temp.cleanup()

    def operation(self, action, account, payload=None):
        body = json.dumps(dict(action=action, account=account, payload=payload))
        try:
            result = subprocess.run([str(self.binary)], input=body, text=True, capture_output=True, check=True)
            decoded = json.loads(result.stdout)
        except (OSError, ValueError, subprocess.CalledProcessError):
            raise ProbeError("keychain_operation_failed") from None
        return decoded.get("payload")


def account_key(profile):
    return hashlib.sha256((MOODLE + ":" + profile).encode()).hexdigest()


def site_info(client, token):
    status, info = client.call("core_webservice_get_site_info", token)
    if not isinstance(info, dict) or type(info.get("userid")) is not int or info["userid"] <= 0:
        raise ProbeError("identity_not_confirmed", status)
    if not isinstance(info.get("functions"), list):
        raise ProbeError("function_catalog_unavailable", status)
    functions = {f["name"] for f in info["functions"] if isinstance(f, dict) and isinstance(f.get("name"), str)}
    return info, functions


def login(client, vault, profile, use_existing_token=False):
    _, config = client.public_config()
    if config.get("enablewebservices") != 1 or config.get("enablemobilewebservice") != 1:
        raise ProbeError("mobile_service_disabled")
    if use_existing_token:
        token = secret_input("貼上由校方允許流程取得的本人 Moodle token（不顯示）：")
    else:
        # Moodle LOGIN_VIA_APP=1; browser/embedded flows must not be impersonated here.
        if config.get("typeoflogin") != 1:
            raise ProbeError("browser_login_required")
        username = secret_input("Moodle 帳號（不顯示）：")
        password = secret_input("Moodle 密碼（不顯示；僅送往校方 HTTPS）：")
        try:
            status, response = client.request("/login/token.php", fields={
                "username": username, "password": password, "service": "moodle_mobile_app",
            })
        finally:
            username = password = None
        token = response.get("token") if isinstance(response, dict) else None
        if not isinstance(token, str) or not token:
            raise ProbeError("token_not_received", status)
        # Do not store or use privatetoken, browser cookies, or the login password.
        response = None
    info, functions = site_info(client, token)
    payload = dict(token=token, userid=info["userid"])
    vault.operation("store", account_key(profile), payload)
    token = payload = None
    emit("identity_verified_token_saved_to_keychain", identity_verified=True,
         readonly_functions={f: f in functions for f in sorted(READ_FUNCTIONS)},
         phase_1_complete=False)


def submission_observation(payload):
    if not isinstance(payload, dict) or not isinstance(payload.get("lastattempt"), dict):
        raise ProbeError("unverified_submission_structure")
    attempt = payload["lastattempt"]
    allowed = {"new", "draft", "submitted", "reopened"}
    def state(key):
        item = attempt.get(key)
        value = item.get("status") if isinstance(item, dict) else None
        return value if isinstance(value, str) and value in allowed else "unknown"
    return dict(individual_state=state("submission"), team_state=state("teamsubmission"),
                graded=attempt.get("graded") if type(attempt.get("graded")) is bool else None,
                completion_inferred=False)


def own_courses(client, token):
    course_function = "core_course_get_enrolled_courses_by_timeline_classification"
    courses, offset = {}, 0
    for _ in range(20):
        _, page = client.call(course_function, token, {"classification": "inprogress", "limit": 50, "offset": offset})
        emit("course_page_schema", schema=shape(page))
        if not isinstance(page, dict) or not isinstance(page.get("courses"), list):
            raise ProbeError("unverified_course_structure")
        batch = page["courses"]
        if not batch:
            break
        previous = len(courses)
        for course in batch:
            if not isinstance(course, dict) or type(course.get("id")) is not int or course["id"] <= 0:
                raise ProbeError("unverified_course_identifier")
            courses[course["id"]] = course
        if len(courses) == previous:
            raise ProbeError("course_page_repeated")
        next_offset = page.get("nextoffset")
        if type(next_offset) is not int or next_offset <= offset:
            raise ProbeError("unverified_course_pagination")
        offset = next_offset
    else:
        raise ProbeError("course_pagination_limit")
    return courses


def current_term():
    now = datetime.now(timezone(timedelta(hours=8)))
    year = now.year - 1911
    return (year - 1, 2) if now.month <= 7 else (year, 1)


def term_pattern():
    year, semester = current_term()
    return re.compile(r"(?<![0-9])" + str(year) + r"[-_\s]?" + str(semester) + r"(?![0-9])")


def has_current_term_hint(course):
    pattern = term_pattern()
    return sum(bool(pattern.search(str(course.get(field, "")))) for field in ("fullname", "shortname", "idnumber")) >= 2


def inventory(client, vault, profile):
    saved = vault.operation("load", account_key(profile))
    if not isinstance(saved, dict) or not isinstance(saved.get("token"), str):
        raise ProbeError("keychain_token_missing")
    info, available = site_info(client, saved["token"])
    if info["userid"] != saved.get("userid"):
        raise ProbeError("account_identity_changed")
    if "core_course_get_enrolled_courses_by_timeline_classification" not in available:
        raise ProbeError("required_read_functions_unavailable")
    courses = own_courses(client, saved["token"])
    # Only aggregate metadata quality; do not print course names, IDs or enrolment history.
    pattern = term_pattern()
    emit("course_metadata_inventory", course_count=len(courses),
         current_term_hint_counts={field: sum(bool(pattern.search(str(c.get(field, "")))) for c in courses.values())
                                   for field in ("fullname", "shortname", "idnumber")},
         names_present=sum(bool(c.get("fullname")) for c in courses.values()),
         course_links_present=sum(isinstance(c.get("viewurl"), str) and c["viewurl"].startswith(MOODLE + "/course/view.php?") for c in courses.values()),
         unset_enddates=sum(c.get("enddate") == 0 for c in courses.values()),
         term_hint="%s-%s" % current_term(), term_mapping_verified=False)


def verify(client, vault, profile, max_courses=3, max_submissions=5):
    saved = vault.operation("load", account_key(profile))
    if not isinstance(saved, dict) or not isinstance(saved.get("token"), str):
        raise ProbeError("keychain_token_missing")
    token = saved["token"]
    info, available = site_info(client, token)
    if info["userid"] != saved.get("userid"):
        raise ProbeError("account_identity_changed")
    emit("identity_verified", identity_verified=True, schema=shape(info),
         readonly_functions={f: f in available for f in sorted(READ_FUNCTIONS)})
    course_function = "core_course_get_enrolled_courses_by_timeline_classification"
    required = {course_function, "mod_assign_get_assignments", "mod_assign_get_submission_status"}
    if not required.issubset(available):
        raise ProbeError("required_read_functions_unavailable")
    timeline = own_courses(client, token)
    courses = {key: value for key, value in timeline.items() if has_current_term_hint(value)}
    emit("own_courses_received", timeline_count=len(timeline), term_hint_matches=len(courses),
         term_hint="%s-%s" % current_term(), semester_mapping_verified=False,
         selection_basis="matching_at_least_two_course_metadata_fields_not_official_enrolment")
    if not courses:
        raise ProbeError("no_current_term_candidates_require_human_review")
    checked = assignment_count = 0
    for course_id in list(courses)[:max_courses]:
        _, result = client.call("mod_assign_get_assignments", token, {"courseids[0]": course_id})
        emit("assignment_schema", schema=shape(result))
        if not isinstance(result, dict) or not isinstance(result.get("courses"), list):
            raise ProbeError("unverified_assignment_structure")
        if result.get("warnings"):
            raise ProbeError("assignment_access_warnings")
        for course in result["courses"]:
            if course.get("id") != course_id or not isinstance(course.get("assignments"), list):
                raise ProbeError("assignment_course_scope_mismatch")
            for assignment in course["assignments"]:
                if type(assignment.get("id")) is not int or assignment["id"] <= 0:
                    raise ProbeError("unverified_assignment_identifier")
                assignment_count += 1
                # No userid is supplied: Moodle must return only the token owner's status.
                if checked >= max_submissions:
                    continue
                _, submission = client.call("mod_assign_get_submission_status", token, {"assignid": assignment["id"]})
                if isinstance(submission, dict) and submission.get("warnings"):
                    raise ProbeError("submission_access_warnings")
                observation = submission_observation(submission)
                emit("submission_schema", schema=shape(submission), observation=observation)
                checked += 1
                # Never infer completion from a grade, overdue flag, draft, or missing response.
    emit("readonly_probe_finished", course_count=len(courses), assignment_count=assignment_count,
         submission_responses=checked, max_courses=max_courses, max_submissions=max_submissions,
         limited_probe=True, status_semantics_verified=False, phase_1_complete=False,
         note="Requires human review of real schema, group submissions and submission-state semantics before integration.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["public", "login", "import-token", "verify", "inventory", "logout", "keychain-self-test"])
    parser.add_argument("--profile", default="default", help="Local alias, not your student number")
    parser.add_argument("--max-courses", type=int, choices=range(1, 21), default=3)
    parser.add_argument("--max-submissions", type=int, choices=range(1, 21), default=5)
    args = parser.parse_args()
    try:
        if args.action == "public":
            public_probe(MoodleClient())
        else:
            with Keychain() as vault:
                if args.action in ("login", "import-token"):
                    login(MoodleClient(), vault, args.profile, args.action == "import-token")
                elif args.action == "verify":
                    verify(MoodleClient(), vault, args.profile, args.max_courses, args.max_submissions)
                elif args.action == "inventory":
                    inventory(MoodleClient(), vault, args.profile)
                elif args.action == "logout":
                    vault.operation("delete", account_key(args.profile))
                    emit("local_token_deleted", server_token_revocation=False)
                else:
                    import secrets
                    key = "self-test-" + secrets.token_hex(16)
                    payload = {"token": secrets.token_hex(32), "userid": 0}
                    try:
                        vault.operation("store", key, payload)
                        if vault.operation("load", key) != payload:
                            raise ProbeError("keychain_roundtrip_failed")
                    finally:
                        vault.operation("delete", key)
                    emit("keychain_self_test_passed", real_credentials_used=False)
        return 0
    except ProbeError as error:
        emit("probe_stopped", diagnostic=error.code, http_status=error.status, phase_1_complete=False)
        return 2
    except (KeyboardInterrupt, EOFError):
        emit("probe_cancelled")
        return 130
    except Exception:
        # Tracebacks and arbitrary exception messages can contain request bodies and URLs.
        emit("probe_stopped", diagnostic="unexpected_local_error", phase_1_complete=False)
        return 2


if __name__ == "__main__":
    sys.exit(main())
