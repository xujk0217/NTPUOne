#!/usr/bin/env python3
"""Read-only graduation page shape diagnostic; session and page stay in memory."""
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


class CreditShape(HTMLParser):
    """Record only numeric formats of the fixed school credit elements."""
    def __init__(self):
        super().__init__()
        self.stack = []
        self.box = None
        self.box_depth = None
        self.credit = None
        self.credit_depth = None
        self.results = []

    def handle_starttag(self, tag, attrs):
        if tag in {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"}:
            return
        attrs = dict(attrs)
        classes = set(attrs.get("class", "").split())
        self.stack.append((tag, attrs.get("id", "")))
        if "credit_box" in classes and self.box is None:
            parent = next((node_id for _, node_id in reversed(self.stack) if node_id in
                           {"tag_total", "tag_chinese", "tag_english", "tag_pe", "tag_general", "mini_general"}), "")
            self.box, self.box_depth = {"section": parent, "main": [], "total": []}, len(self.stack)
        if self.box is not None and self.credit is None:
            for name, css in (("main", "main_credit"), ("total", "total_credit")):
                if css in classes:
                    self.credit, self.credit_depth = name, len(self.stack)
                    break

    def handle_startendtag(self, tag, attrs):
        if tag not in {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"}:
            self.handle_starttag(tag, attrs)
            self.handle_endtag(tag)

    def handle_endtag(self, tag):
        if not self.stack or tag not in [node for node, _ in self.stack]:
            return
        while self.stack and self.stack[-1][0] != tag:
            self.handle_endtag(self.stack[-1][0])
        if self.credit_depth == len(self.stack):
            self.credit = self.credit_depth = None
        if self.box_depth == len(self.stack):
            if self.box and self.box["section"]:
                self.results.append({"section": self.box["section"],
                                     "main": numeric_shape("".join(self.box["main"])),
                                     "total": numeric_shape("".join(self.box["total"]))})
            self.box = self.box_depth = None
        self.stack.pop()

    def handle_data(self, data):
        if self.box is not None and self.credit is not None:
            self.box[self.credit].append(data)


class CategoryShape(HTMLParser):
    """Summarise the exact category selectors used by the App, without values."""
    def __init__(self):
        super().__init__()
        self.stack = []
        self.section = None
        self.item = None
        self.item_depth = None
        self.span = None
        self.span_depth = None
        self.footer = None
        self.footer_depth = None
        self.hidden_depth = None
        self.metrics = []
        self.footers = []
        self.scripts = []
        self.script = None
        self.script_depth = None

    def handle_starttag(self, tag, attrs):
        if tag in {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"}:
            return
        attrs = dict(attrs)
        classes = set(attrs.get("class", "").split())
        self.stack.append((tag, attrs.get("id", ""), classes))
        depth = len(self.stack)
        if "lang-en-US" in classes and self.hidden_depth is None:
            self.hidden_depth = depth
        if tag == "script":
            self.script, self.script_depth = [], depth
        if tag == "section" and attrs.get("id") in {"required", "option", "common", "other"}:
            self.section = attrs["id"]
        if self.section and self.hidden_depth is None:
            if "collapse_col_item" in classes and any("collapse_ul_header" in node[2] for node in self.stack):
                self.item, self.item_depth = [], depth
            if self.item is not None and tag == "span" and self.span is None:
                self.span, self.span_depth = [], depth
            if "collapse_ul_footer" in classes:
                self.footer, self.footer_depth = [], depth

    def handle_startendtag(self, tag, attrs):
        if tag not in {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"}:
            self.handle_starttag(tag, attrs)
            self.handle_endtag(tag)

    def handle_endtag(self, tag):
        if not self.stack or tag not in [node[0] for node in self.stack]:
            return
        while self.stack and self.stack[-1][0] != tag:
            self.handle_endtag(self.stack[-1][0])
        depth = len(self.stack)
        if self.span_depth == depth:
            self.item.append("".join(self.span))
            self.span = self.span_depth = None
        if self.item_depth == depth:
            self.metrics.append({"section": self.section,
                "span_count": len(self.item),
                "spans": [numeric_shape(value) for value in self.item[:8]]})
            self.item = self.item_depth = None
        if self.footer_depth == depth:
            self.footers.append({"section": self.section, "shape": numeric_shape(" ".join(self.footer))})
            self.footer = self.footer_depth = None
        if self.script_depth == depth:
            text = "".join(self.script)
            if re.search(r"credit|學分", text, re.I):
                self.scripts.append({"has_division_by_10_or_100": bool(re.search(r"/\s*(?:10|100)(?![0-9])", text)),
                    "uses_decimal_formatting": bool(re.search(r"toFixed|parseFloat", text)),
                    "uses_integer_parsing": "parseInt" in text})
            self.script = self.script_depth = None
        if self.hidden_depth == depth:
            self.hidden_depth = None
        if tag == "section" and self.stack[-1][1] == self.section:
            self.section = None
        self.stack.pop()

    def handle_data(self, data):
        if self.script is not None:
            self.script.append(data)
        if self.hidden_depth is not None:
            return
        if self.span is not None:
            self.span.append(data)
        if self.footer is not None:
            self.footer.append(data)


class StructureShape(HTMLParser):
    """Locate public labels and surrounding HTML structure without exposing values."""
    LABELS = ("已累計總學分", "系必修", "系選修", "校訂必修學分", "其他學分",
              "外語能力指標檢核", "校定程式設計能力", "學分學程、微學程")
    VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"}

    def __init__(self):
        super().__init__()
        self.nodes = [{"tag": "root", "classes": [], "id": "", "parent": None, "children": [], "text": []}]
        self.stack = [0]
        self.ignored = 0

    def handle_starttag(self, tag, attrs):
        if tag in self.VOID:
            return
        attrs = dict(attrs)
        classes = attrs.get("class", "").split()
        if tag in {"script", "style"} or "lang-en-US" in classes:
            self.ignored += 1
        parent = self.stack[-1]
        node = {"tag": tag, "classes": classes, "id": attrs.get("id", ""),
                "parent": parent, "children": [], "text": []}
        self.nodes.append(node)
        index = len(self.nodes) - 1
        self.nodes[parent]["children"].append(index)
        self.stack.append(index)

    def handle_startendtag(self, tag, attrs):
        if tag not in self.VOID:
            self.handle_starttag(tag, attrs)
            self.handle_endtag(tag)

    def handle_endtag(self, tag):
        if not any(self.nodes[index]["tag"] == tag for index in self.stack[1:]):
            return
        while len(self.stack) > 1:
            node = self.nodes[self.stack.pop()]
            if node["tag"] in {"script", "style"} or "lang-en-US" in node["classes"]:
                self.ignored = max(0, self.ignored - 1)
            if node["tag"] == tag:
                break

    def handle_data(self, data):
        if not self.ignored:
            self.nodes[self.stack[-1]]["text"].append(data)

    def text_under(self, index):
        node = self.nodes[index]
        return " ".join(node["text"] + [self.text_under(child) for child in node["children"]])

    def describe(self, index):
        node = self.nodes[index]
        classes = [name for name in node["classes"] if
                   re.fullmatch(r"[A-Za-z][A-Za-z0-9_-]{0,45}", name) and
                   not re.search(r"[0-9]{3,}", name) and
                   re.search(r"credit|total|sum|title|info|result|card|score|progress|graduation|number|box|area|container|flex|col|item|note", name, re.I)]
        safe_id = node["id"] if node["id"] in {"tag_total", "tag_chinese", "tag_english", "tag_pe", "tag_general", "mini_general", "required", "option", "common", "other"} else ""
        return {"tag": node["tag"], "classes": classes[:8], "id": safe_id,
                "shape": numeric_shape(self.text_under(index))}

    def result(self):
        result = []
        for label in self.LABELS:
            matches = [index for index, node in enumerate(self.nodes)
                       if label in " ".join(" ".join(node["text"]).split())]
            for index in matches[:2]:
                levels = []
                current = index
                for _ in range(4):
                    parent = self.nodes[current]["parent"]
                    if parent is None:
                        break
                    levels.append({"node": self.describe(parent),
                                   "children": [self.describe(child) for child in self.nodes[parent]["children"][:12]]})
                    current = parent
                result.append({"label": label, "levels": levels})
        return result


def numeric_shape(value):
    """Never include actual numbers or unrecognised text in diagnostics."""
    value = " ".join(value.split())
    digits = re.findall(r"[0-9]+", value)
    return {"digit_lengths": [len(part) for part in digits[:8]],
            "contains_decimal": bool(re.search(r"[0-9][.．][0-9]", value)),
            "contains_separator": bool(re.search(r"[/／]", value)),
            "has_unit": any(unit in value for unit in ("學分", "門", "類", "項")),
            "starts_with_zero": bool(digits and len(digits[0]) > 1 and digits[0].startswith("0"))}


def validated_descriptor(text):
    try:
        descriptor = json.loads(text)
        login, target, fields = descriptor["form_url"], descriptor["base_url"], descriptor["formData"]
        host = urllib.parse.urlsplit(login).hostname
        if host not in {"cof.ntpu.edu.tw", "ohs01.ntpu.edu.tw"}:
            raise ValueError()
        if login != f"https://{host}/pls/pm/stud_system.signin":
            raise ValueError()
        if target != f"https://{host}/pls/univer/query_all_course.judge?func=9_m":
            raise ValueError()
        if not isinstance(fields, dict) or set(fields) != {"id", "pw"} or not all(isinstance(v, str) and v for v in fields.values()):
            raise ValueError()
        return descriptor
    except (KeyError, ValueError, TypeError):
        raise ProbeError("school_graduation_bridge_unverified") from None


def fetch_graduation(descriptor):
    descriptor = validated_descriptor(json.dumps(descriptor))
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}),
        urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()), school.BridgeNoRedirect())
    identity = descriptor["formData"]["id"]
    try:
        for login in (True, False):
            request = urllib.request.Request(descriptor["form_url"] if login else descriptor["base_url"],
                data=urllib.parse.urlencode(descriptor["formData"]).encode() if login else None,
                headers={"User-Agent": "NTPUOne-Local-Academic-Probe/0.1"})
            with opener.open(request, timeout=25) as response:
                raw = response.read(2 * 1024 * 1024 + 1)
                if len(raw) > 2 * 1024 * 1024:
                    raise ProbeError("school_response_too_large")
                if not login:
                    body = raw.decode(response.headers.get_content_charset() or "big5", errors="replace")
                    if identity not in body:
                        raise ProbeError("school_identity_unverified")
                    return body
    except urllib.error.HTTPError as error:
        raise ProbeError("school_bridge_http_error", error.code) from None
    except (urllib.error.URLError, OSError):
        raise ProbeError("school_bridge_network_or_tls_error") from None
    finally:
        descriptor["formData"].clear()


def main():
    try:
        client = school.Session()
        _, _, login_page = client.request("/login")
        if re.search(r"captcha|samlrequest|oauthsso", login_page, re.I):
            raise ProbeError("school_interactive_challenge_requires_browser")
        forms = [f for f in school.parsed(login_page).forms if f["method"] == "POST" and
                 {"_token", "username", "password"}.issubset(f["fields"]) and
                 urllib.parse.urljoin(school.ORIGIN, f["action"]) == school.ORIGIN + "/login"]
        if len(forms) != 1 or not forms[0]["fields"]["_token"]:
            raise ProbeError("school_login_form_not_verified")
        username = secret_input("新版校務帳號（不顯示）：")
        password = secret_input("新版校務密碼（不顯示；僅送往校方 HTTPS）：")
        fields = dict(_token=forms[0]["fields"]["_token"], username=username, password=password)
        try:
            _, url, body = client.request("/login", fields)
        finally:
            username = password = fields = None
        if not school.confirmed_session(url, school.parsed(body)):
            raise ProbeError("school_session_not_confirmed")
        path = "/get-projects/10?" + urllib.parse.urlencode({"url": school.ACADEMIC_TARGETS["graduation"]})
        _, _, response = client.request(path)
        descriptor = validated_descriptor(response)
        response = body = None
        try:
            html = fetch_graduation(descriptor)
        finally:
            descriptor["formData"].clear()
        page = CreditShape()
        page.feed(html)
        if not page.results or not any(item["section"] == "tag_total" for item in page.results):
            raise ProbeError("school_graduation_schema_unverified")
        category = CategoryShape()
        category.feed(html)
        structure = StructureShape()
        structure.feed(html)
        emit("graduation_credit_shape", boxes=page.results, category_metrics=category.metrics,
             category_footers=category.footers, credit_script_flags=category.scripts,
             summary_structure=structure.result(), actual_values_hidden=True,
             raw_page_saved=False, session_saved=False)
        return 0
    except ProbeError as error:
        emit("graduation_diagnostic_stopped", diagnostic=error.code, http_status=error.status)
        return 2
    except (KeyboardInterrupt, EOFError):
        emit("graduation_diagnostic_cancelled")
        return 130
    except Exception:
        emit("graduation_diagnostic_stopped", diagnostic="unexpected_local_error")
        return 2


if __name__ == "__main__":
    sys.exit(main())
