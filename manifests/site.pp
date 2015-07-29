# server config

# class for all servers
class standard {
    include base
}

node 'db1.miraheze.org' {
    include standard
    include role::db
}

node 'misc1.miraheze.org' {
    include standard
    include role::ganglia
    include role::icinga
    include role::mail
    include role::dns
    include role::piwik
    include role::redis
}

node 'mw1.miraheze.org' {
    include standard
    include role::mediawiki
}

node /^ns[13]\.miraheze\.org$/ {
    include standard
    include role::dns
}

# ensures all servers have basic class if puppet runs
node default {
    include standard
}
