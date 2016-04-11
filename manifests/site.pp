# server config

# class for all servers
class standard {
    include base
}

node 'bacula1' {
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

node 'db1.miraheze.org' {
    include standard
    include role::db
    include bacula::client
}

node 'misc1.miraheze.org' {
    include standard
    include role::ganglia
    include role::icinga
    include role::irc
    include role::mail
    include role::dns
    include role::piwik
    include role::redis
    include role::surveys
    include role::phabricator
    include bacula::client
}

node /^mw[12]\.miraheze\.org$/ {
    include standard
    include role::mediawiki

    if $::hostname == 'mw1' {
        include bacula::client
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

# ensures all servers have basic class if puppet runs
node default {
    include standard
}
