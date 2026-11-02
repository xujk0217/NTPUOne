#!/usr/bin/env python3
"""Fresh-session login investigation only; no grade scraping or timetable writes."""
from __future__ import annotations

import argparse
import hashlib
from html.parser import HTMLParser
import http.cookiejar
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

from academic_probe import Keychain, ProbeError, emit, secret_input

ORIGIN = "https://my.ntpu.edu.tw"
COURSE_LIST = "https://ohs01.ntpu.edu.tw/pls/univer/u0001.query_all_course.judge?func=3_m"
BRIDGE_LOGIN = "https://cof.ntpu.edu.tw/pls/pm/stud_system.signin"
BRIDGE_COURSE_LIST = "https://cof.ntpu.edu.tw/pls/univer/u0001.query_all_course.judge?func=3_m"
BRIDGE_ROUTES = {BRIDGE_LOGIN: BRIDGE_COURSE_LIST,
    "https://ohs01.ntpu.edu.tw/pls/pm/stud_system.signin": COURSE_LIST}
PROJECT_PATH = "/get-projects/10?" + urllib.parse.urlencode({"url": COURSE_LIST})
ACADEMIC_TARGETS = {
    "grades": COURSE_LIST.replace("func=3_m", "func=5_m"),
    "rank": COURSE_LIST.replace("func=3_m", "func=8_m"),
    "graduation": "https://ohs01.ntpu.edu.tw/pls/univer/query_all_course.judge?func=9_m",
}
ACADEMIC_PROJECT_PATHS = {"/get-projects/10?" + urllib.parse.urlencode({"url": target})
                          for target in ACADEMIC_TARGETS.values()}


def same_origin(url):
    part = urllib.parse.urlsplit(url)
    return (part.scheme == "https" and part.hostname == "my.ntpu.edu.tw"
            and part.port in (None, 443) and part.username is None and part.password is None)


class SchoolRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if not same_origin(newurl) or code not in (301, 302, 303):
            raise ProbeError("school_redirect_requires_browser_review", code)
        path = urllib.parse.urlsplit(newurl).path.lower()
        if re.search(r"(?:^|/)(?:logout|delete|remove|save|update|submit|withdraw)(?:/|$)", path):
            raise ProbeError("school_redirect_action_blocked", code)
        return super().redirect_request(req, fp, code, msg, headers, newurl)


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.forms, self.links, self.current = [], [], None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "form":
            self.current = dict(action=attrs.get("action", ""), method=attrs.get("method", "GET").upper(), fields={})
            self.forms.append(self.current)
        elif tag == "input" and self.current is not None and attrs.get("name"):
            # Values stay only in process memory, never in diagnostic output.
            self.current["fields"][attrs["name"]] = attrs.get("value", "")
        elif tag in ("a", "iframe", "frame"):
            target = attrs.get("href" if tag == "a" else "src")
            if target:
                self.links.append(target)

    def handle_endtag(self, tag):
        if tag == "form":
            self.current = None


class Session:
    def __init__(self):
        self.cookies = http.cookiejar.CookieJar()
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}),
            urllib.request.HTTPCookieProcessor(self.cookies), SchoolRedirect())

    def request(self, path, fields=None):
        if path not in {"/", "/login", PROJECT_PATH} | ACADEMIC_PROJECT_PATHS or (fields is not None and path != "/login"):
            raise ProbeError("school_endpoint_not_verified")
        headers = {"User-Agent": "NTPUOne-Local-Academic-Probe/0.1"}
        if path == PROJECT_PATH or path in ACADEMIC_PROJECT_PATHS:
            headers.update({"Accept": "application/json", "X-Requested-With": "XMLHttpRequest"})
        request = urllib.request.Request(ORIGIN + path,
            data=urllib.parse.urlencode(fields).encode() if fields is not None else None,
            headers=headers)
        try:
            with self.opener.open(request, timeout=25) as response:
                body = response.read(2 * 1024 * 1024 + 1)
                if len(body) > 2 * 1024 * 1024:
                    raise ProbeError("school_response_too_large")
                if not same_origin(response.url):
                    raise ProbeError("school_origin_changed")
                return response.status, response.url, body.decode("utf-8", errors="replace")
        except urllib.error.HTTPError as error:
            raise ProbeError("school_http_error", error.code) from None
        except (urllib.error.URLError, OSError):
            raise ProbeError("school_network_or_tls_error") from None

    def restore(self, payload):
        if not isinstance(payload, dict) or not isinstance(payload.get("cookies"), list):
            raise ProbeError("school_session_missing")
        for value in payload["cookies"]:
            if value.get("domain", "").lstrip(".") != "my.ntpu.edu.tw":
                raise ProbeError("school_cookie_scope_mismatch")
            cookie = http.cookiejar.Cookie(
                version=0, name=value["name"], value=value["value"], port=None, port_specified=False,
                domain=value["domain"], domain_specified=value["domain_specified"],
                domain_initial_dot=value["domain_initial_dot"], path=value["path"], path_specified=True,
                secure=value["secure"], expires=value["expires"], discard=value["discard"],
                comment=None, comment_url=None, rest=value["rest"], rfc2109=False)
            self.cookies.set_cookie(cookie)

    def export(self):
        return {"cookies": [dict(name=c.name, value=c.value, domain=c.domain,
            domain_specified=c.domain_specified, domain_initial_dot=c.domain_initial_dot,
            path=c.path, secure=c.secure, expires=c.expires, discard=c.discard, rest=c._rest)
            for c in self.cookies if c.domain.lstrip(".") == "my.ntpu.edu.tw"]}


class BridgeNoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        raise ProbeError("school_bridge_redirect_requires_review")


def read_course_list(descriptor):
    """Only the two exact validated endpoints; cookies disappear with this call."""
    descriptor = bridge_descriptor(json.dumps(descriptor))
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}),
        urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()), BridgeNoRedirect())
    own_id = descriptor["formData"]["id"]
    try:
        for login in (True, False):
            request = urllib.request.Request(descriptor["form_url"] if login else descriptor["base_url"],
                data=urllib.parse.urlencode(descriptor["formData"]).encode() if login else None,
                headers={"User-Agent": "NTPUOne-Local-Academic-Probe/0.1"})
            with opener.open(request, timeout=25) as response:
                raw = response.read(2 * 1024 * 1024 + 1)
                if len(raw) > 2 * 1024 * 1024:
                    raise ProbeError("school_response_too_large")
                charset = response.headers.get_content_charset() or "big5"
                body = raw.decode(charset, errors="replace")
                if not login:
                    return response.status, body, own_id
            descriptor["formData"].clear()
    except urllib.error.HTTPError as error:
        raise ProbeError("school_bridge_http_error", error.code) from None
    except (urllib.error.URLError, OSError):
        raise ProbeError("school_bridge_network_or_tls_error") from None
    finally:
        descriptor["formData"].clear()


class CoursePage(HTMLParser):
    """Private cell values remain in memory; callers choose safe diagnostics."""
    def __init__(self):
        super().__init__()
        self.rows, self.links, self.text = [], [], []
        self.row = self.cell = None
        self.hidden = 0

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag in ("script", "style"):
            self.hidden += 1
        if tag == "tr":
            self.row = []
        if tag in ("th", "td"):
            self.cell = []
        if tag == "a" and attrs.get("href"):
            self.links.append(attrs["href"])

    def handle_endtag(self, tag):
        if tag in ("script", "style"):
            self.hidden = max(0, self.hidden - 1)
        if tag in ("td", "th") and self.cell is not None:
            if self.row is not None:
                self.row.append(" ".join(" ".join(self.cell).split()))
            self.cell = None
        if tag == "tr" and self.row is not None:
            self.rows.append(self.row)
            self.row = None

    def handle_data(self, data):
        if self.hidden:
            return
        self.text.append(data)
        if self.cell is not None:
            self.cell.append(data)


def parsed(text):
    result = Page()
    result.feed(text)
    return result


def verified_course_menu(text):
    """Read JSON embedded by the portal, never evaluate page JavaScript."""
    match = re.search(r"\bvar arr\s*=\s*(\[.*?\]);", text, re.S)
    try:
        items = json.loads(match.group(1)) if match else None
    except (ValueError, TypeError):
        raise ProbeError("school_menu_schema_unverified") from None
    if not isinstance(items, list) or len(items) > 1000:
        raise ProbeError("school_menu_schema_unverified")
    matches = [item for item in items if isinstance(item, dict) and
               item.get("page_name") == "選課清單" and item.get("project_id") == 10 and
               item.get("url") == COURSE_LIST]
    if len(matches) != 1:
        raise ProbeError("school_course_menu_unverified")
    return matches[0]


def verified_enrolment(text, own_id):
    page = CoursePage()
    page.feed(text)
    headers = ["", "科目名稱(與組別)", "核課資訊", "授課老師", "上課時間@教室",
               "類別", "學分/時數", "開課系級", "備註"]
    if not page.rows or page.rows[0] != headers or len(page.rows) > 301:
        raise ProbeError("school_enrolment_schema_unverified")
    terms = set()
    for link in page.links:
        part = urllib.parse.urlsplit(link)
        if part.scheme or part.netloc or part.path != "../univer/course_check_m.dt_e":
            continue
        query = urllib.parse.parse_qs(part.query)
        if query.get("stud_no") != [own_id]:
            raise ProbeError("school_enrolment_identity_mismatch")
        year, term = query.get("year1", []), query.get("term1", [])
        if len(year) != 1 or len(term) != 1 or not re.fullmatch(r"1\d{2}", year[0]) or term[0] not in ("1", "2"):
            raise ProbeError("school_enrolment_term_unverified")
        terms.add((year[0], term[0]))
    if len(terms) != 1:
        raise ProbeError("school_enrolment_term_unverified")
    courses = []
    for row in page.rows[1:]:
        if len(row) != len(headers):
            raise ProbeError("school_enrolment_schema_unverified")
        match = re.search(r"\(([A-Z]\d{4})\)\s*$", row[1])
        if not match:
            raise ProbeError("school_course_code_unverified")
        # Only this state has been observed live. Unknown/withdrawn/pending rows
        # cannot silently join an import candidate list.
        if row[2] != "已核准":
            raise ProbeError("school_selection_state_requires_review")
        courses.append(dict(code=match[1], name=row[1][:match.start()].strip(),
                            selection_info=row[2], teacher=row[3], schedule=row[4]))
    if not courses or len({c["code"] for c in courses}) != len(courses):
        raise ProbeError("school_course_list_empty_or_duplicate")
    year, term = next(iter(terms))
    return dict(year=year, term=term, courses=courses)


def catalog_compatibility(enrolment):
    """Audit existing CourseGet's column contract; not an App import parser."""
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), BridgeNoRedirect())
    endpoint = "https://sea.cc.ntpu.edu.tw/pls/dev_stud/course_query_all.queryByKeyword"
    checked = 0
    for course in enrolment["courses"]:
        fields = dict(qYear=enrolment["year"], qTerm=enrolment["term"], courseno=course["code"],
                      cour="", teach="", week="", seq1="A", seq2="M")
        request = urllib.request.Request(endpoint, data=urllib.parse.urlencode(fields).encode(),
            headers={"User-Agent": "NTPUOne-Local-Academic-Probe/0.1"})
        try:
            with opener.open(request, timeout=25) as response:
                raw = response.read(2 * 1024 * 1024 + 1)
                if len(raw) > 2 * 1024 * 1024:
                    raise ProbeError("catalog_response_too_large")
        except urllib.error.HTTPError as error:
            raise ProbeError("catalog_http_error", error.code) from None
        except (urllib.error.URLError, OSError):
            raise ProbeError("catalog_network_or_tls_error") from None
        page = CoursePage()
        page.feed(raw.decode("big5", errors="replace"))
        matches = [row for row in page.rows if len(row) >= 15 and row[3] == course["code"]]
        if not matches or any(not row[7] or not row[8] or not row[13] for row in matches):
            raise ProbeError("catalog_courseget_contract_unverified")
        checked += 1
    return checked


def bridge_descriptor(text):
    """Validate only; credentials must never appear in diagnostic output."""
    try:
        value = json.loads(text)
    except (ValueError, TypeError):
        raise ProbeError("school_bridge_schema_unverified") from None
    if (not isinstance(value, dict) or not isinstance(value.get("form_url"), str) or
            value.get("form_url") not in BRIDGE_ROUTES or
            value.get("base_url") != BRIDGE_ROUTES[value["form_url"]] or
            not isinstance(value.get("formData"), dict) or
            set(value["formData"]) != {"id", "pw"} or
            not all(isinstance(v, str) and v for v in value["formData"].values())):
        raise ProbeError("school_bridge_schema_unverified")
    return value


def navigation_observation(client, text):
    verified_course_menu(text)
    status, _, body = client.request(PROJECT_PATH)
    descriptor = bridge_descriptor(body)
    # This command deliberately stops before sending formData to the bridge host.
    login, destination = descriptor["form_url"], descriptor["base_url"]
    descriptor["formData"].clear()
    descriptor = body = None
    emit("school_course_navigation_verified", http_status=status,
         course_menu="選課清單", bridge_login=login,
         readonly_destination=destination,
         bridge_credentials_forwarded=False, official_enrolment_verified=False,
         phase_2_complete=False)


def confirmed_session(url, page):
    login_form = any({"username", "password"}.issubset(f["fields"]) for f in page.forms)
    actions = [f["action"] for f in page.forms] + page.links
    logout = any(same_origin(urllib.parse.urljoin(ORIGIN, action)) and
                 urllib.parse.urlsplit(action).path.rstrip("/").endswith("/logout") for action in actions)
    return same_origin(url) and urllib.parse.urlsplit(url).path != "/login" and not login_form and logout


def summary(status, url, page):
    # Route segments not in this list are hidden, including any possible student identifier.
    known = set("api student students course courses grade grades score scores schedule academic transcript login logout home dashboard curriculum enrollment pls pm".split())
    routes = []
    for link in page.links:
        target = urllib.parse.urlsplit(urllib.parse.urljoin(ORIGIN, link))
        if not same_origin(target.geturl()):
            continue
        if not re.search("course|grade|score|schedule|academic|transcript|curriculum|enroll", target.path, re.I):
            continue
        parts = [part if part.lower() in known else "<segment>" for part in target.path.split("/") if part]
        route = "/" + "/".join(parts)
        if route not in routes:
            routes.append(route)
    emit("school_session_observation", http_status=status,
         session_evidence=confirmed_session(url, page), identity_verified=False,
         redacted_academic_routes=routes, official_enrolment_verified=False,
         phase_2_complete=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["login", "inspect", "navigation", "catalog-verify", "logout-local"])
    parser.add_argument("--profile", default="default", help="Local alias, not student number")
    args = parser.parse_args()
    account = hashlib.sha256((ORIGIN + ":" + args.profile).encode()).hexdigest()
    try:
        with Keychain() as vault:
            if args.action == "logout-local":
                vault.operation("delete", account)
                emit("school_local_session_deleted", server_session_revoked=False)
                return 0
            client = Session()
            if args.action == "login":
                _, _, text = client.request("/login")
                page = parsed(text)
                if re.search(r"captcha|samlrequest|oauthsso", text, re.I):
                    raise ProbeError("school_interactive_challenge_requires_browser")
                forms = [f for f in page.forms if f["method"] == "POST" and
                         {"_token", "username", "password"}.issubset(f["fields"]) and
                         urllib.parse.urljoin(ORIGIN, f["action"]) == ORIGIN + "/login"]
                if len(forms) != 1 or not forms[0]["fields"]["_token"]:
                    raise ProbeError("school_login_form_not_verified")
                username = secret_input("新版校務帳號（不顯示）：")
                password = secret_input("新版校務密碼（不顯示；僅送往校方 HTTPS）：")
                fields = dict(_token=forms[0]["fields"]["_token"], username=username, password=password)
                try:
                    status, url, text = client.request("/login", fields)
                finally:
                    username = password = fields = None
                page = parsed(text)
                summary(status, url, page)
                if not confirmed_session(url, page):
                    raise ProbeError("school_session_not_confirmed")
                vault.operation("store", account, client.export())
                emit("fresh_school_session_saved_to_keychain", phase_2_complete=False)
            else:
                client.restore(vault.operation("load", account))
                status, url, text = client.request("/")
                page = parsed(text)
                summary(status, url, page)
                if not confirmed_session(url, page):
                    raise ProbeError("school_session_expired_or_unverified")
                if args.action == "navigation":
                    navigation_observation(client, text)
                elif args.action == "catalog-verify":
                    verified_course_menu(text)
                    _, _, descriptor_body = client.request(PROJECT_PATH)
                    descriptor = bridge_descriptor(descriptor_body)
                    descriptor_body = None
                    try:
                        status, course_body, own_id = read_course_list(descriptor)
                    finally:
                        descriptor["formData"].clear()
                    enrolment = verified_enrolment(course_body, own_id)
                    course_body = own_id = None
                    checked = catalog_compatibility(enrolment)
                    emit("school_enrolment_catalog_verified", http_status=status,
                         identity_verified=True, academic_year=enrolment["year"], term=enrolment["term"],
                         course_count=len(enrolment["courses"]), catalog_matched_courses=checked,
                         official_enrolment_verified=True, selection_states_verified=True,
                         courseget_column_contract_verified=True, phase_2_complete=True,
                         app_import_implemented=False, timetable_written=False)
        return 0
    except ProbeError as error:
        emit("school_probe_stopped", diagnostic=error.code, http_status=error.status, phase_2_complete=False)
        return 2
    except (KeyboardInterrupt, EOFError):
        emit("school_probe_cancelled")
        return 130
    except Exception:
        emit("school_probe_stopped", diagnostic="unexpected_local_error", phase_2_complete=False)
        return 2


if __name__ == "__main__":
    sys.exit(main())
