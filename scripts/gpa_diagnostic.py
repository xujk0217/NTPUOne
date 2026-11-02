#!/usr/bin/env python3
"""Read-only GPA structure diagnostic. No credentials, grades or raw pages are output/saved."""
from __future__ import annotations
import http.cookiejar
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from html.parser import HTMLParser
import sis_probe as school
from academic_probe import ProbeError, emit, secret_input
from graduation_diagnostic import numeric_shape

GPA = re.compile(r"GPA|平均績點|學分績點|績點", re.I)
VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"}

class Node:
    def __init__(self, tag="root", attrs=(), parent=None):
        self.tag, self.attrs, self.parent = tag, dict(attrs), parent
        self.children, self.parts = [], []
    def text(self):
        if self.tag in {"script", "style", "input", "form"}: return ""
        return " ".join(self.parts + [child.text() for child in self.children])
    def shape(self):
        classes = [v for v in self.attrs.get("class", "").split() if len(v) <= 50 and re.fullmatch(r"[A-Za-z_-]+", v)]
        ident = self.attrs.get("id", "")
        return {"tag": self.tag, "classes": classes[:8], "id": ident if re.fullmatch(r"(?i)(?:gpa|grades?|scores?|summary)(?:[-_][A-Za-z]+)*", ident) else "", "numeric_shape": numeric_shape(self.text())}

class GPAShape(HTMLParser):
    def __init__(self):
        super().__init__(); self.root = Node(); self.stack = [self.root]; self.nodes = []
    def handle_starttag(self, tag, attrs):
        node = Node(tag, attrs, self.stack[-1]); self.stack[-1].children.append(node); self.nodes.append(node)
        if tag not in VOID: self.stack.append(node)
    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        if tag not in VOID: self.handle_endtag(tag)
    def handle_endtag(self, tag):
        for i in range(len(self.stack)-1, 0, -1):
            if self.stack[i].tag == tag: del self.stack[i:]; break
    def handle_data(self, data): self.stack[-1].parts.append(data)
    def result(self):
        output = []
        for node in self.nodes:
            if not GPA.search(node.text()) or any(GPA.search(child.text()) for child in node.children): continue
            levels = []; current = node
            for _ in range(4):
                if current is None: break
                levels.append({"node": current.shape(), "children": [child.shape() for child in current.children[:12]]})
                current = current.parent
            output.append({"label": "GPA／績點", "levels": levels})
        return output[:12]

def fetch_grades(client):
    path = "/get-projects/10?" + urllib.parse.urlencode({"url": school.ACADEMIC_TARGETS["grades"]})
    _, _, body = client.request(path)
    try:
        descriptor = json.loads(body); login = descriptor["form_url"]; target = descriptor["base_url"]; fields = descriptor["formData"]
        host = urllib.parse.urlsplit(login).hostname
        if host not in {"cof.ntpu.edu.tw", "ohs01.ntpu.edu.tw"} or login != f"https://{host}/pls/pm/stud_system.signin" or target != f"https://{host}/pls/univer/u0001.query_all_course.judge?func=5_m": raise ValueError()
        if not isinstance(fields, dict) or set(fields) != {"id", "pw"} or not all(isinstance(v, str) and v for v in fields.values()): raise ValueError()
    except (ValueError, KeyError, TypeError): raise ProbeError("school_grade_bridge_unverified") from None
    identity = fields["id"]
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()), school.BridgeNoRedirect())
    try:
        for is_login in (True, False):
            request = urllib.request.Request(login if is_login else target, data=urllib.parse.urlencode(fields).encode() if is_login else None, headers={"User-Agent": "NTPUOne-Local-GPA-Shape/0.1"})
            with opener.open(request, timeout=25) as response:
                raw = response.read(2 * 1024 * 1024 + 1)
                if len(raw) > 2 * 1024 * 1024: raise ProbeError("school_response_too_large")
                if not is_login:
                    html = raw.decode(response.headers.get_content_charset() or "big5", errors="replace")
                    if identity not in html: raise ProbeError("school_identity_unverified")
                    return html
    except urllib.error.HTTPError as error: raise ProbeError("school_bridge_http_error", error.code) from None
    except (urllib.error.URLError, OSError): raise ProbeError("school_bridge_network_or_tls_error") from None
    finally: fields.clear()

def main():
    try:
        client = school.Session(); _, _, body = client.request("/login")
        if re.search(r"captcha|samlrequest|oauthsso", body, re.I): raise ProbeError("school_interactive_challenge_requires_browser")
        forms = [f for f in school.parsed(body).forms if f["method"] == "POST" and {"_token", "username", "password"}.issubset(f["fields"]) and urllib.parse.urljoin(school.ORIGIN, f["action"]) == school.ORIGIN + "/login"]
        if len(forms) != 1 or not forms[0]["fields"]["_token"]: raise ProbeError("school_login_form_not_verified")
        username = secret_input("新版校務帳號（不顯示）："); password = secret_input("新版校務密碼（不顯示）：")
        fields = dict(_token=forms[0]["fields"]["_token"], username=username, password=password)
        try: _, url, body = client.request("/login", fields)
        finally: username = password = fields = None
        if not school.confirmed_session(url, school.parsed(body)): raise ProbeError("school_session_not_confirmed")
        html = fetch_grades(client); shape = GPAShape(); shape.feed(html); html = body = None
        emit("grade_gpa_shape", structures=shape.result(), actual_values_hidden=True, raw_page_saved=False, session_saved=False)
        return 0
    except ProbeError as error: emit("gpa_diagnostic_stopped", diagnostic=error.code, http_status=error.status); return 2
    except (KeyboardInterrupt, EOFError): emit("gpa_diagnostic_cancelled"); return 130
    except Exception: emit("gpa_diagnostic_stopped", diagnostic="unexpected_local_error"); return 2

if __name__ == "__main__": sys.exit(main())
