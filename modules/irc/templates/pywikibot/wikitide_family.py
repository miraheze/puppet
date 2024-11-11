# MANAGED BY PUPPET
from pywikibot import family


class Family(family.Family):  # noqa: D101

    name = 'wikitide'
    langs = {
        <%- @family_langs.each do |dbname, params| {-%>
        "<%= dbname %>": "<%= params['domain'] %>",
        <%- end -%>
    }

    def scriptpath(self, code):
        return {
            <%- @family_langs.each do |dbname, params| {-%>
            "<%= dbname %>": "/w",
            <%- end -%>
        }[code]

    def protocol(self, code):
        return {
            <%- @family_langs.each do |dbname, params| {-%>
            "<%= dbname %>": "https",
            <%- end -%>
        }[code]
