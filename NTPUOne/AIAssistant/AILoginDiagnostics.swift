import Foundation

struct AILoginSite: Codable {
    var https: Bool
    var host: String
    var pathShape: String

    static func make(_ url: URL) -> AILoginSite {
        let host = url.host?.lowercased() ?? "unknown"
        let school = host == "ntpu.edu.tw" || host.hasSuffix(".ntpu.edu.tw")
        return AILoginSite(https: url.scheme == "https", host: school ? host : "[external]", pathShape: pathShape(url.path))
    }
    static func pathShape(_ path: String) -> String {
        let known: Set<String> = ["auth", "saml", "saml2", "login", "signin", "sign-in", "sso", "idp", "adfs", "ls", "cas", "index.php", "login.php", "acs", "callback", "oauth", "authorize", "account", "accounts", "authn", "saml2auth", "profile", "saml2", "sso.php"]
        return "/" + path.split(separator: "/").map { known.contains($0.lowercased()) ? String($0).lowercased() : ":route" }.joined(separator: "/")
    }
}

struct AILoginFormShape: Codable {
    var method: String
    var actionHost: String
    var actionHTTPS: Bool
    var actionPathShape: String
    var usernameFields: Int
    var passwordFields: Int
    var hiddenFields: Int
    var hasSAML: Bool
    var hasOTP: Bool
}
struct AILoginPageShape: Codable {
    var forms: [AILoginFormShape]
    var hasCaptcha: Bool
    var hasOTP: Bool
}
struct AILoginDiagnosticEvent: Codable {
    var stage: String
    var site: AILoginSite?
    var status: Int?
    var shape: AILoginPageShape?
}
struct AILoginDiagnosticReport: Codable {
    var schema = 1
    var authenticated: Bool
    var events: [AILoginDiagnosticEvent]
    var credentialsRead = false
    var cookiesRead = false
    var rawPagesSaved = false
}

enum AILoginDiagnosticScript {
    // Only structural counts. Never inspect input values, text, HTML, cookies,
    // storage, query strings, form names or authentication responses.
    static let source = #"""
    (() => {
      if (location.protocol !== 'https:' || !(location.hostname === 'ntpu.edu.tw' || location.hostname.endsWith('.ntpu.edu.tw'))) return null;
      const known = new Set(['auth','saml','saml2','login','signin','sign-in','sso','idp','adfs','ls','cas','index.php','login.php','acs','callback','oauth','authorize','account','accounts','authn','saml2auth','profile','sso.php']);
      const shape = path => '/' + path.split('/').filter(Boolean).map(x => known.has(x.toLowerCase()) ? x.toLowerCase() : ':route').join('/');
      const fields = form => Array.from(form.querySelectorAll('input')).slice(0,100);
      const otp = input => input.autocomplete === 'one-time-code' || /otp|one.?time|verification.?code/i.test(input.name || '');
      const forms = Array.from(document.forms).slice(0,8).map(form => {
        const action = new URL(form.getAttribute('action') || location.pathname, location.href);
        const inputs = fields(form);
        return {method: (form.method || 'get').toLowerCase(), actionHost: (action.hostname === 'ntpu.edu.tw' || action.hostname.endsWith('.ntpu.edu.tw')) ? action.hostname : '[external]',
          actionHTTPS: action.protocol === 'https:', actionPathShape: shape(action.pathname),
          usernameFields: inputs.filter(x => x.autocomplete === 'username' || ['email'].includes(x.type) || /^(username|user|account|userid|loginname)$/i.test(x.name || '')).length,
          passwordFields: inputs.filter(x => x.type === 'password').length,
          hiddenFields: inputs.filter(x => x.type === 'hidden').length,
          hasSAML: inputs.some(x => /^(SAMLRequest|SAMLResponse|RelayState)$/i.test(x.name || '')),
          hasOTP: inputs.some(otp)};
      });
      return {forms, hasCaptcha: !!document.querySelector('iframe[src*="challenges.cloudflare.com"],iframe[src*="recaptcha"],.g-recaptcha,input[name*="captcha"]'),
        hasOTP: Array.from(document.querySelectorAll('input')).slice(0,100).some(otp)};
    })();
    """#
}

/// Runs only after an explicit tap, in the verified school login page's main frame.
/// Credentials are arguments, never embedded in script text, persisted or logged.
enum AIStoredSchoolLoginScript {
    static let preflight = #"""
    const expected = 'https://saml2.ntpu.edu.tw', path = '/module.php/ntpuauth/login';
    if (location.origin !== expected || location.pathname !== path) return false;
    const all = Array.from(document.querySelectorAll('input'));
    if (document.querySelector('iframe[src*="captcha" i], .g-recaptcha, [data-sitekey]') ||
        all.some(x => /captcha|recaptcha|one.?time|otp|verification.?code/i.test((x.name || '') + ' ' + (x.id || '') + ' ' + (x.autocomplete || '')))) return false;
    return Array.from(document.forms).filter(form => {
      let action; try { action = new URL(form.getAttribute('action') || location.href, location.href); } catch (_) { return false; }
      if (action.origin !== expected || action.pathname !== path || (form.method || '').toLowerCase() !== 'post' || typeof form.requestSubmit !== 'function') return false;
      const inputs = Array.from(form.querySelectorAll('input'));
      return inputs.filter(x => (x.name || '').toLowerCase() === 'account' && x.type === 'text' && !x.disabled).length === 1 &&
        inputs.filter(x => (x.name || '').toLowerCase() === 'password' && x.type === 'password' && !x.disabled).length === 1 &&
        inputs.filter(x => x.type === 'password').length === 1 &&
        inputs.filter(x => (x.name || '').toLowerCase() === 'authstate' && x.type === 'hidden').length === 1;
    }).length === 1;
    """#
    static let source = #"""
    const expected = 'https://saml2.ntpu.edu.tw';
    const path = '/module.php/ntpuauth/login';
    if (location.origin !== expected || location.pathname !== path) return false;
    const all = Array.from(document.querySelectorAll('input'));
    if (document.querySelector('iframe[src*="captcha" i], .g-recaptcha, [data-sitekey]') ||
        all.some(x => /captcha|recaptcha|one.?time|otp|verification.?code/i.test((x.name || '') + ' ' + (x.id || '') + ' ' + (x.autocomplete || '')))) return false;
    const forms = Array.from(document.forms).filter(form => {
      let action; try { action = new URL(form.getAttribute('action') || location.href, location.href); } catch (_) { return false; }
      if (action.origin !== expected || action.pathname !== path || (form.method || '').toLowerCase() !== 'post') return false;
      const inputs = Array.from(form.querySelectorAll('input'));
      const account = inputs.filter(x => (x.name || '').toLowerCase() === 'account' && x.type === 'text' && !x.disabled);
      const password = inputs.filter(x => (x.name || '').toLowerCase() === 'password' && x.type === 'password' && !x.disabled);
      const passwords = inputs.filter(x => x.type === 'password');
      const state = inputs.filter(x => (x.name || '').toLowerCase() === 'authstate' && x.type === 'hidden');
      return account.length === 1 && password.length === 1 && passwords.length === 1 && state.length === 1;
    });
    if (forms.length !== 1 || typeof forms[0].requestSubmit !== 'function') return false;
    const form = forms[0], account = form.querySelector('input[name="account"]'), password = form.querySelector('input[name="password"]');
    if (!account || !password || typeof username !== 'string' || !username || typeof secret !== 'string' || !secret) return false;
    const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')?.set;
    if (!setter) return false;
    try {
      setter.call(account, username); account.dispatchEvent(new Event('input', {bubbles:true})); account.dispatchEvent(new Event('change', {bubbles:true}));
      setter.call(password, secret); password.dispatchEvent(new Event('input', {bubbles:true})); password.dispatchEvent(new Event('change', {bubbles:true}));
      const action = new URL(form.getAttribute('action') || location.href, location.href);
      if (location.origin !== expected || location.pathname !== path || action.origin !== expected || action.pathname !== path || form.method.toLowerCase() !== 'post' ||
          [account, password].some(x => x.formAction && new URL(x.formAction, location.href).origin !== expected)) throw new Error('form_changed');
      form.requestSubmit(); return true;
    } catch (_) { setter.call(account, ''); setter.call(password, ''); return false; }
    """#
}
