# servers

node 'bacula1.miraheze.org' {
    include base
    include bacula::director
    # mysql crashes
    # include role::dbreplication
    include role::salt::minions
}

node /^cp[245]\.miraheze\.org$/ {
    include base
    include role::varnish
    include role::salt::minions
}

node 'db4.miraheze.org' {
    include base
    include role::db
    include role::postgresql
    include puppetdb::database
    include bacula::client
    include role::salt::minions
    include prometheus::mysqld_exporter
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
    include role::prometheus
    include role::salt::minions
    include prometheus::php_fpm
}

node 'misc3.miraheze.org' {
    include base
    include role::lizardfs
    include role::services
    include role::salt::minions
}

node 'misc4.miraheze.org' {
    include base
    include bacula::client
    include role::phabricator
    include role::salt::masters
    include role::salt::minions
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

node 'puppet1.miraheze.org' {
    include base
    include bacula::client
    include role::puppetserver
    include role::salt::minions
}

node /^lizardfs[12]\.miraheze\.org$/ {
    include base
    include bacula::client
    include role::lizardfs
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
