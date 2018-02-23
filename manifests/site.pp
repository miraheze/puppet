# servers

node 'bacula1.miraheze.org' {
    include base
    include bacula::director
}

node /^cp[24]\.miraheze\.org$/ {
    include base
    include role::varnish
}

node 'nfs1.miraheze.org' {
    include base
    include role::staticserver
    include bacula::client
}

node /^db[234].miraheze.org$/ {
    include base
    include role::db
    include bacula::client
}

node 'misc1.miraheze.org' {
    include base
    include role::icinga
    include role::irc
    include role::mail
    include role::dns
    include role::phabricator
    include bacula::client
}

node 'misc2.miraheze.org' {
    include base
    include role::redis
    include role::ganglia
    include role::piwik
}

node /^mw[123]\.miraheze\.org$/ {
    include base
    include role::mediawiki
}

node 'ns1.miraheze.org' {
    include base
    include role::dns
}

node 'parsoid1.miraheze.org' {
    include base
    include role::parsoid
}

node 'puppet1.miraheze.org' {
    include base
    include bacula::client
    include puppetmaster
}
node 'test1.miraheze.org' {
    include base
    include puppetmaster # Temporary for testing new Puppet version
}

# ensures all servers have basic class if puppet runs
node default {
    include base
}
