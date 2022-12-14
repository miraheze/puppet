# === Class role::mediawiki::jobchron
class role::mediawiki::jobchron {
    include role::redis
    include mediawiki::jobqueue::chron

    motd::role { 'role::mediawiki::jobchron':
        description => 'MediaWiki Jobchron server',
    }
}
