# server config

# class for all servers
class standard {
    include base
}

node /^cp[12]\.miraheze\.org$/ {
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
    include role::surveys
}

node /^mw[12]\.miraheze\.org$/ {
    $users_defined = 'true'
    include standard
    include role::mediawiki

    class { 'users':
        groups => ['mediawiki-admins'],
    }
}

node 'ns1.miraheze.org' {
    include standard
    include role::dns
}

# Vultr instance running both GDNSD and Varnish
node 'ns3.miraheze.org' {
    include standard
    include role::dns
    include role::varnish
}

node 'parsoid1.miraheze.org' {
    include standard
    include role::parsoid
}

# ensures all servers have basic class if puppet runs
node default {
    include standard
}
