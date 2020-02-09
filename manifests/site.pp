# servers

node 'bacula1.miraheze.org' {
    include base
    include bacula::director
    # mysql crashes
    # include role::dbreplication
    include role::salt::minions
}

node /^cp[234]\.miraheze\.org$/ {
    include base
    include role::varnish
    include role::salt::minions
}

node /^db[46]\.miraheze\.org$/ {
    include base
    include role::db
    include role::postgresql
    include puppetdb::database
    include bacula::client
    include role::salt::minions
    include prometheus::mysqld_exporter
}

node 'db5.miraheze.org' {
    include base
    include role::db
    include bacula::client
    include role::salt::minions
    include prometheus::mysqld_exporter
}

node 'lizardfs6.miraheze.org' {
    include base
    include bacula::client
    include role::gluster
    include role::mediawiki
    include role::salt::minions
    include prometheus::php_fpm
}

node 'misc1.miraheze.org' {
    include base
    include role::dns
    include role::grafana
    include role::icinga2
    include role::irc
    include role::mail
    include role::roundcubemail
    include role::salt::minions
    include prometheus::php_fpm
}

node 'misc2.miraheze.org' {
    include base
    include role::redis
    include role::matomo
    include role::salt::minions
    include prometheus::php_fpm
    include prometheus::redis_exporter
}

node 'misc3.miraheze.org' {
    include base
    include role::services
    include role::salt::minions
}

node 'misc4.miraheze.org' {
    include base
    include bacula::client
    include role::phabricator
    include role::prometheus
    include role::salt::masters
    include role::salt::minions
    include role::services
    include prometheus::php_fpm
}

node /^mw[123]\.miraheze\.org$/ {
    include base
    include role::mediawiki
    include role::salt::minions
    include prometheus::php_fpm
}

node 'ns1.miraheze.org' {
    include base
    include role::dns
}

node /^puppet[12]\.miraheze\.org$/ {
    include base
    include bacula::client
    include role::puppetserver
    include role::salt::minions
}

node 'test1.miraheze.org' {
    include base
    include role::mediawiki
    include role::salt::minions
    include prometheus::php_fpm
}

# ensures all servers have basic class if puppet runs
node default {
    include base
    include role::salt::minions
}
