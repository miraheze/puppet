# servers

node 'bacula1.miraheze.org' {
    include base
    include bacula::director
    include role::salt::minions
}

node /^cp[245]\.miraheze\.org$/ {
    include base
    include role::varnish
    include role::salt::minions
}

node 'nfs1.miraheze.org' {
    include base
    include role::staticserver
    include bacula::client
    include role::salt::minions
}

node /^db[23].miraheze.org$/ {
    include base
    include role::db
    include bacula::client
    include role::salt::minions
}

node 'db4.miraheze.org' {
    include base
    include role::db
    include role::postgresql
    include bacula::client
    include role::salt::minions
}

node 'misc1.miraheze.org' {
    include base
    include role::icinga
    include role::irc
    include role::mail
    include role::dns
    include role::phabricator
    include bacula::client
    include role::salt::minions
}

node 'misc2.miraheze.org' {
    include base
    include role::redis
    include role::ganglia
    include role::piwik
    include role::salt::minions
}

node 'misc3.miraheze.org' {
    include base
    include role::parsoid
    include role::salt::masters
    include role::salt::minions
}

node /^mw[123]\.miraheze\.org$/ {
    include base
    include role::mediawiki
    include role::salt::minions
}

node 'ns1.miraheze.org' {
    include base
    include role::dns
}

node 'puppet1.miraheze.org' {
    include base
    include bacula::client
    include puppetmaster
    include role::salt::minions
}

node 'test1.miraheze.org' {
    include base
    include role::mediawiki
    include role::salt::minions
}

# ensures all servers have basic class if puppet runs
node default {
    include base
    include role::salt::minions
}
