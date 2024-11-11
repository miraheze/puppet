# MANAGED BY PUPPET
from pywikibot import family


class Family(family.Family):  # noqa: D101

    name = 'wikitide'
    langs = {
        <% family_langs.each |$dbname, $params| {-%>
        '<%= $dbname %>': '<%= $params["domain"] %>',
        <% } -%>
    }

    def scriptpath(self, code):
        return {
            <% family_langs.each |$dbname, $params| {-%>
            '<%= $dbname %>': '/w',
            <% } -%>
        }[code]

    def protocol(self, code):
        return {
            <% family_langs.each |$dbname, $params| {-%>
            '<%= $dbname %>': 'https',
            <% } -%>
        }[code]
