# server config

# class for all servers
class standard {
    include base
}

node 'bacula1.miraheze.org' {
    include standard
    include bacula::director
}

node /^cp[12]\.miraheze\.org$/ {
    include standard
    include role::varnish

    if $::hostname == 'cp1' {
        include role::staticserver
        include bacula::client
    }
}

node /^db[23].miraheze.org$/ {
    include standard
    include role::db
    include bacula::client
}

node 'misc1.miraheze.org' {
    include standard
    include role::icinga
    include role::irc
    include role::mail
    include role::dns
    include role::phabricator
    include bacula::client
}

node 'misc2.miraheze.org' {
    include standard
    include role::redis
    include role::ganglia
    include role::piwik
}

node /^mw[12]\.miraheze\.org$/ {
    include standard
    include role::mediawiki

    if $::hostname == 'mw1' {
        include acme
    }
}

node 'ns1.miraheze.org' {
    include standard
    include role::dns
}

node 'parsoid1.miraheze.org' {
    include standard
    include role::parsoid
}

node 'puppet1.miraheze.org' {
    include standard
    include bacula::client
    include puppetmaster
}
node 'test1.miraheze.org' {
	include standard
	include role::mediawiki
}

# ensures all servers have basic class if puppet runs
node default {
    include standard
}
