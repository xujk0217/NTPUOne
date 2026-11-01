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
        if path not in ("/", "/login") or (fields is not None and path != "/login"):
            raise ProbeError("school_endpoint_not_verified")
        request = urllib.request.Request(ORIGIN + path,
            data=urllib.parse.urlencode(fields).encode() if fields is not None else None,
            headers={"User-Agent": "NTPUOne-Local-Academic-Probe/0.1"})
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


def parsed(text):
    result = Page()
    result.feed(text)
    return result


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
    parser.add_argument("action", choices=["login", "inspect", "logout-local"])
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
