"""
Checks proposed usernames against Miraheze's Username Policy and
MediaWiki:Global_title_blacklist.
https://meta.miraheze.org/wiki/Username_Policy
https://meta.miraheze.org/wiki/MediaWiki:Global_title_blacklist
"""

import re
import unicodedata
from typing import Optional

# Roles/positions that would create a false impression of authority.
AUTHORITY_TERMS = {
    "admin", "administrator", "sysop",
    "bureaucrat", "interface-admin", "interfaceadmin",
    "checkuser", "oversight", "suppress",
    "steward", "global-admin", "globaladmin",
    "miraheze-staff", "mirahezestaff", "wikitide-staff", "wikitidefoundation",
    "trustandsafety", "trust-and-safety",
    "staff", "moderator", "mod", "cvt", "global-moderator",
    "director", "official", "founder", "owner", "operator",
    "developer", "support", "helpdesk",
    "sysadmin", "superadmin", "root", "sudo",
    "miraheze", "wikitide", "wikiforge", "meta", "mediawiki",
}

BOT_TERMS = {
    "bot", "script", "robot", "crawler", "spider", "scraper",
    "automated", "autobot", "botaccount",
}

# All patterns translated directly from MediaWiki:Global_title_blacklist.
# The blacklist is case-insensitive by default; all patterns use re.IGNORECASE.
# re.search() is used (equivalent to the blacklist's leading/trailing .*).
_BLACKLIST_PATTERNS = [
    # IPv4 address
    (re.compile(
        r"^([1-9]?\d|1\d\d|2([0-4]\d|5[0-5]))\."
        r"([1-9]?\d|1\d\d|2([0-4]\d|5[0-5]))\."
        r"([1-9]?\d|1\d\d|2([0-4]\d|5[0-5]))\."
        r"([1-9]?\d|1\d\d|2([0-4]\d|5[0-5]))(\/.*)?$"
    ), "Username resembles an IPv4 address"),

    # IPv6 address
    (re.compile(
        r"^[0-9A-Fa-f]{0,10}:([0-9A-Fa-f]{0,10}:)*([0-9A-Fa-f]{0,10})?"
        r"(?:\/(12[0-8]|1[01][0-9]|[1-9]?\d))?$"
    ), "Username resembles an IPv6 address"),

    # More than 50 characters
    (re.compile(r".{51}"), "Username exceeds 50 characters"),

    # Platform names (also caught by AUTHORITY_TERMS, but included for completeness)
    (re.compile(r"\bmiraheze", re.IGNORECASE), "Username contains 'miraheze'"),
    (re.compile(r"\bvanished", re.IGNORECASE), "Username contains 'vanished'"),
    (re.compile(r"\bwikitide", re.IGNORECASE), "Username contains 'wikitide'"),
    (re.compile(r"\bwikiforge", re.IGNORECASE), "Username contains 'wikiforge'"),

    # Spam
    (re.compile(r"\breview", re.IGNORECASE), "Username contains 'review'"),

    # Inappropriate content — English
    (re.compile(r"\brape(?!r)", re.IGNORECASE), "Username contains 'rape'"),
    (re.compile(r"fuck", re.IGNORECASE), "Username contains 'fuck'"),
    (re.compile(r"f\*ck", re.IGNORECASE), "Username contains 'f*ck'"),
    (re.compile(r"h[i1!]tl[e3]r", re.IGNORECASE), "Username contains 'hitler'"),
    (re.compile(r"p[e3\xea]+n+[i1!]+s", re.IGNORECASE), "Username contains 'penis'"),
    (re.compile(r"b[i1!]+tch", re.IGNORECASE), "Username contains 'bitch'"),
    (re.compile(r"btch", re.IGNORECASE), "Username contains 'btch'"),
    (re.compile(r"c[o0]cksuck", re.IGNORECASE), "Username contains 'cocksuck'"),
    (re.compile(r"aut[i1!]s(m|t\b)", re.IGNORECASE), "Username contains 'autism/autist'"),
    (re.compile(r"ass+ho+l+e", re.IGNORECASE), "Username contains 'asshole'"),
    (re.compile(r"sh[i1!]t", re.IGNORECASE), "Username contains 'shit'"),
    (re.compile(r"c[o0]+ck", re.IGNORECASE), "Username contains 'cock'"),
    (re.compile(r"d[i1!]ck", re.IGNORECASE), "Username contains 'dick'"),
    (re.compile(r"v[a4]nd[a4]l", re.IGNORECASE), "Username contains 'vandal'"),
    (re.compile(r"vag[i1!]na", re.IGNORECASE), "Username contains 'vagina'"),
    (re.compile(r"d[i1!]+ldo", re.IGNORECASE), "Username contains 'dildo'"),
    (re.compile(r"scr[o0]tum", re.IGNORECASE), "Username contains 'scrotum'"),
    (re.compile(r"stu+p[i1!]d", re.IGNORECASE), "Username contains 'stupid'"),
    (re.compile(r"sp[a4]m", re.IGNORECASE), "Username contains 'spam'"),
    (re.compile(r"w[o0]+rst", re.IGNORECASE), "Username contains 'worst'"),
    (re.compile(r"s[o0]+ckpu+pp+[e3]t", re.IGNORECASE), "Username contains 'sockpuppet'"),
    (re.compile(r"p[i1!]+ss+", re.IGNORECASE), "Username contains 'piss'"),
    (re.compile(r"n[i1!]gg+([e3]r|[a4]h)", re.IGNORECASE), "Username contains a racial slur"),
    (re.compile(r"fag\.?g+ot", re.IGNORECASE), "Username contains a slur"),
    (re.compile(r"p[o0\*]r[mn]", re.IGNORECASE), "Username contains 'porn'"),
    (re.compile(r"[i!1][nm]c[e3]s[7t]", re.IGNORECASE), "Username contains 'incest'"),
    (re.compile(r"w[e3]d[h4r]+[o0]", re.IGNORECASE), "Username matches abuse pattern"),
    (re.compile(r"[l7]+[e3]zz+[o0]", re.IGNORECASE), "Username contains a slur"),
    (re.compile(r"gdpr", re.IGNORECASE), "Username contains 'GDPR'"),
    (re.compile(r"t[e3]rms\.?[o0]f\.?s[e3]rv[i1!]c[e3]", re.IGNORECASE), "Username contains 'terms of service'"),
    (re.compile(r"t[e3]rms\.?[o0]f\.?us[e3]", re.IGNORECASE), "Username contains 'terms of use'"),
    (re.compile(r"c[o0]d[e3]\.?[o0]f\.?c[o0]nduct", re.IGNORECASE), "Username contains 'code of conduct'"),
    (re.compile(r"p[o0]l[i1!]cy", re.IGNORECASE), "Username contains 'policy'"),

    # Inappropriate content — Italian
    (re.compile(r"[nm][e3]rd[4eao]", re.IGNORECASE), "Username contains Italian profanity"),
    (re.compile(r"c[a4]?[sz][o0]", re.IGNORECASE), "Username contains Italian profanity"),
    (re.compile(r"s[7t]r[o0]n[sz][i1!]", re.IGNORECASE), "Username contains Italian profanity"),
    (re.compile(r"v[a4@]ff[a4@][mn]cul[o0]", re.IGNORECASE), "Username contains Italian profanity"),
    (re.compile(r"c[a4@]c[a4@]", re.IGNORECASE), "Username contains Italian profanity"),
    (re.compile(r"puzzolente", re.IGNORECASE), "Username contains Italian profanity"),
    (re.compile(r"d[e3]gu[sz][7t][a@][nm][e3]rch[i1!][e3]", re.IGNORECASE), "Username contains Italian profanity"),
    (re.compile(r"b[@a4][sz][7t][@a4]rd", re.IGNORECASE), "Username contains 'bastard'"),
    (re.compile(r"lur[i1]d[o0]", re.IGNORECASE), "Username contains Italian profanity"),
    (re.compile(r"l[@a4]t[r7][i1!][nm][e3]", re.IGNORECASE), "Username contains Italian profanity"),
    (re.compile(r"p[i1!][scz][scz][i1!][o0@]", re.IGNORECASE), "Username contains Italian profanity"),
    (re.compile(r"s[e3]d[e3]r[i1!][nm][o0@]", re.IGNORECASE), "Username contains Italian profanity"),

    # Privileged role impersonation
    (re.compile(r"\badmin", re.IGNORECASE), "Username contains 'admin'"),
    (re.compile(r"\bsysop", re.IGNORECASE), "Username contains 'sysop'"),
    (re.compile(r"\bmoderator", re.IGNORECASE), "Username contains 'moderator'"),
    (re.compile(r"\bdirector", re.IGNORECASE), "Username contains 'director'"),
    (re.compile(r"\bcheckuser", re.IGNORECASE), "Username contains 'checkuser'"),
    (re.compile(r"\bste[vw]ard", re.IGNORECASE), "Username contains 'steward'"),

    # Impersonation of specific community members / abuse patterns
    (re.compile(r"dm[e3]hus", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"mr\.?j[a4]r[o0]sl[a4]v[i1!]k", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"nd\.?k[i1!]ll+[a4]", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"rh[i1!]+n[o0]+s\.?f", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"r[e3]c[e3]pt[i1!][o0]n\d{3}", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"v[o0]+[i1!]+d", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"zpp+[i1!]+x", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"d[a4]rkm[a4]tt[e3]rm[a4]n\d{4}", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"w[e3]dhr[o0]", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"[jyi][a4@][nm]l[a4@]", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"[i1!]nkst[e3]r", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"s[a4]nt[a4]\.?cl[a4]us", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"dec[i1!]du[o0]usw[a4]t[e3]r\d{5}", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"sn[o0]w[i1][e3]", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"m[a4]g[o0]gr[e3]", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"bugamb[i1][7l][i1]a", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"dn[e3]hus", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"[e3]hus", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"ra[i1]dar", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"burn[i1!]ngpr[i1!]nc[e3]ss", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"[a4]rcv[e3]rs[i1]n", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"bu[e3]h[li]", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"[i1!lyj][s$][a4@][i1!lyj]", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"\d{2}-k[i1!]ju", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"br[a4]nd[o0]n\.?wm", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"[a4]g[e3]nt\.?[i1!]s[a4][i1!]", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"n[o0]t\.?[a4]r[a4]ch[a4]m", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"m[a4]c[5f][a4]n\d{3}", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"un[i!1]v[e3]rs[a4][li]\.?[o0]m[e3]g[a4]", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"w[a4]k[i1l]s?\d{3}", re.IGNORECASE), "Username impersonates a community member"),
    (re.compile(r"[すず]{2}ね[-\u2010\u30fc\u2015\u2212\u301c~\uff70\u30a0]う"), "Username impersonates a community member"),

    # Spam / abuse
    (re.compile(r"plaquenil", re.IGNORECASE), "Username matches spam pattern"),
    (re.compile(r"alexandravoicu", re.IGNORECASE), "Username matches abuse pattern"),
    (re.compile(r"l[o0]ckreason", re.IGNORECASE), "Username matches abuse pattern"),
    (re.compile(r"custom.*reason", re.IGNORECASE), "Username matches abuse pattern"),
    (re.compile(r"l[o0]ck.*reason", re.IGNORECASE), "Username matches abuse pattern"),
    (re.compile(r"bl[o0]ck.*reason", re.IGNORECASE), "Username matches abuse pattern"),
    (re.compile(r"w[i!1][kc][i!1]p[3e]d[i!1][a@4]", re.IGNORECASE), "Username impersonates Wikipedia"),
    (re.compile(r"y[a4@]ml[a4@]", re.IGNORECASE), "Username impersonates a community member"),
]

_LEET = str.maketrans({
    "0": "o", "1": "i", "3": "e", "4": "a",
    "5": "s", "6": "g", "7": "t", "8": "b", "@": "a",
    "$": "s", "!": "i",
})


class PolicyChecker:
    def __init__(self, extra_blocked: Optional[list[str]] = None):
        self.extra_blocked = set(t.lower() for t in (extra_blocked or []))

    def check(self, name: str, light: bool = False) -> tuple[bool, str]:
        if not name or not name.strip():
            return False, "Username is empty."

        normalised = self._normalise(name)

        checks = [
            self._check_blacklist,
            self._check_authority_impersonation,
            self._check_email,
            self._check_extra_blocked,
        ]

        if not light:
            checks += [
                self._check_bot_impersonation,
                self._check_promotional,
            ]

        for fn in checks:
            ok, reason = fn(name, normalised)
            if not ok:
                return False, reason

        return True, ""

    def _check_blacklist(self, name: str, _norm: str) -> tuple[bool, str]:
        for pattern, reason in _BLACKLIST_PATTERNS:
            if pattern.search(name):
                return False, reason
        return True, ""

    def _check_authority_impersonation(self, name: str, norm: str) -> tuple[bool, str]:
        name_lower = name.lower()
        norm_lower = norm.lower()
        for term in AUTHORITY_TERMS:
            if term in name_lower or term in norm_lower:
                return False, f"Username contains '{term}'"
        return True, ""

    def _check_bot_impersonation(self, name: str, _norm: str) -> tuple[bool, str]:
        name_lower = name.lower()
        for term in BOT_TERMS:
            if term in name_lower:
                return False, f"Username implies an automated account (contains '{term}')"
        return True, ""

    def _check_email(self, name: str, _norm: str) -> tuple[bool, str]:
        if re.search(r"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}", name):
            return False, "Username contains an e-mail address"
        return True, ""

    def _check_extra_blocked(self, name: str, norm: str) -> tuple[bool, str]:
        name_lower = name.lower()
        norm_lower = norm.lower()
        for term in self.extra_blocked:
            if term in name_lower or term in norm_lower:
                return False, f"Username contains blocked term '{term}'"
        return True, ""

    def _check_promotional(self, name: str, _norm: str) -> tuple[bool, str]:
        name_lower = name.lower()
        if re.search(r"https?://|www\.", name_lower):
            return False, "Username contains a URL"
        if re.search(r"\.(com|org|net|io|co|gg|tv|xyz)\b", name_lower):
            return False, "Username appears to be a domain name"
        return True, ""

    @staticmethod
    def _normalise(name: str) -> str:
        decomposed = unicodedata.normalize("NFKD", name)
        stripped   = "".join(c for c in decomposed if unicodedata.category(c) != "Mn")
        return stripped.translate(_LEET).lower()
