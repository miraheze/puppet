# servers

node 'bacula1.miraheze.org' {
    include base
    include bacula::director
    # mysql crashes
    # include role::dbreplication
    include role::salt::minions
}

node /^cp[2348]\.miraheze\.org$/ {
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

node 'db5.miraheze.org' {
    include base
    include role::db
    include bacula::client
    include role::salt::minions
    include prometheus::mysqld_exporter
}

node 'db6.miraheze.org' {
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

node 'gluster1.miraheze.org' {
    include base
    include bacula::client
    include role::gluster
    include role::salt::minions
}

node 'jobrunner1.miraheze.org' {
    include base
    include role::redis
    include role::mediawiki
    include role::salt::minions
}

node 'mail1.miraheze.org' {
    include base
    include role::mail
    include role::roundcubemail
    include role::salt::minions
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

node /^mw[1234567]\.miraheze\.org$/ {
    include base
    include role::mediawiki
    include role::salt::minions
    include prometheus::php_fpm
}

node /^ns[12]\.miraheze\.org$/ {
    include base
    include role::dns
}

node 'phab1.miraheze.org' {
    include base
    include bacula::client
    include role::phabricator
    include role::salt::minions
    include prometheus::php_fpm
}

node 'puppet1.miraheze.org' {
    include base
    include bacula::client
    include role::puppetserver
    include role::salt::minions
}

node 'puppet2.miraheze.org' {
    include base
    include bacula::client
    include role::postgresql
    include puppetdb::database
    include role::puppetserver
    include role::salt::masters
    include role::salt::minions
}

node /^rdb[12]\.miraheze\.org$/ {
    include base
    include role::redis
    include role::salt::minions
    include prometheus::redis_exporter
}

node /^services2[12]\.miraheze\.org$/ {
    include base
    include role::services
    include role::salt::minions
}

node 'test1.miraheze.org' {
    include base
    include role::mediawiki
    include role::salt::minions
    include prometheus::php_fpm
}

node 'test2.miraheze.org' {
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
