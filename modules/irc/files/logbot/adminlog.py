#!/usr/bin/python3

import sys
sys.path.insert(0, r'/etc/irclogbot/mwclient')

import mwclient  # noqa: E402
import datetime  # noqa: E402

sys.path.insert(0, r'/etc/irclogbot/mwclient')

months = ["January", "February", "March", "April", "May", "June", "July",
          "August", "September", "October", "November", "December"]


def log(config, message, project, author):
    if config.enable_identica:
        import statusnet

    if config.wiki_category:
        import re

    site = mwclient.Site(config.wiki_connection,
                         path=config.wiki_path,
                         clients_useragent='Miraheze-LogBot/0.2 run by Miraheze SRE',
                         consumer_token=config.wiki_consumer_token,
                         consumer_secret=config.wiki_consumer_secret,
                         access_token=config.wiki_access_token,
                         access_secret=config.wiki_access_secret
                        )
    if config.enable_projects:
        project = project.capitalize()
        pagename = config.wiki_page % project
    else:
        pagename = config.wiki_page

    page = site.Pages[pagename]
    if page.redirect:
        page = next(page.links())

    text = page.text()
    lines = text.split('\n')
    position = 0
    # Um, check the date
    now = datetime.datetime.utcnow()
    logline = "* %02d:%02d %s: %s" % (now.hour, now.minute, author, message)

    # Try extracting latest date header
    header = "=" * config.wiki_header_depth
    header_date = None
    for line in lines:
        position += 1
        if line.startswith(header):
            try:
                header_date = [int(x) for x in line.strip(" =").split("-")]
            except ValueError:
                header_date = None
            break
    if header_date != [now.year, now.month, now.day]:
        lines.insert(position - 1, "")
        lines.insert(position - 1, logline)
        lines.insert(position - 1, now.strftime("{0} %Y-%m-%d {0}".format(header)))
    else:
        lines.insert(position, logline)
    if config.wiki_category:
        if not re.search(r'\[\[Category:' + config.wiki_category + r'\]\]',
                         text):
            lines.append('<noinclude>[[Category:'
                         + config.wiki_category + ']]</noinclude>')

    page.save(
        '\n'.join(lines),
        "%s (%s)" % (message, author),
        bot=getattr(config, 'wiki_bot', True)
    )

    micro_update = ("%s: %s" % (author, message))[:140]

    if config.enable_identica:
        snapi = statusnet.StatusNet({'user': config.identica_username,
                                     'passwd': config.identica_password,
                                     'api': 'https://identi.ca/api'})
        snapi.update(micro_update)

    if config.enable_twitter:
        import twitter
        twitter_api = twitter.Api(**config.twitter_api_params)
        twitter_api.PostUpdate(micro_update)

    revdata = site.api('query', prop='info',
                       inprop='url', revids=page.revision)
    return list(revdata['query']['pages'].values())[0]['canonicalurl']
