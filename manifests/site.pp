# server config

# class for all servers
class standard {
    include base
}

node 'cp1.miraheze.org' {
    include standard
    include role::varnish
}

node 'db1.miraheze.org' {
    include standard
    include role::db
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
}

node 'mw1.miraheze.org' {
    $users_defined = 'true'
    include standard
    include role::mediawiki

    class { 'users':
        groups => ['mediawiki-admins'],
    }
}

node /^ns[13]\.miraheze\.org$/ {
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
