# role: mediawiki::bots — not used standalone; bots171 runs role::irc which includes this
class role::mediawiki::bots {
    include mediawiki::rename_bot

    system::role { 'mediawiki::bots':
        description => 'MediaWiki bots',
    }
}
