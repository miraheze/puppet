# servers

node 'bacula2.miraheze.org' {
    include base
    include bacula::director
}

node /^cloud[12]\.miraheze\.org$/ {
    include base
}

node /^cp[3678]\.miraheze\.org$/ {
    include base
    include role::varnish
}

node 'db4.miraheze.org' {
    include base
    include role::db
    include role::postgresql
    include puppetdb::database
    include bacula::client
    include prometheus::mysqld_exporter
}

node 'db6.miraheze.org' {
    include base
    include role::dbreplication
    include bacula::client
    include prometheus::mysqld_exporter
}

node 'db7.miraheze.org' {
    include base
    include role::db
    include bacula::client
    include prometheus::mysqld_exporter
}

node 'db9.miraheze.org' {
    include base
    include role::db
    include bacula::client
    include prometheus::mysqld_exporter
}

node 'db10.miraheze.org' {
    include base
    include role::dbreplication
    include bacula::client
    include prometheus::mysqld_exporter
}

node 'gluster1.miraheze.org' {
    include base
    include bacula::client
    include role::gluster
}

node 'gluster2.miraheze.org' {
    include base
    include role::gluster
}

node 'jobrunner1.miraheze.org' {
    include base
    include role::redis
    include role::mediawiki
    include prometheus::redis_exporter
}

node 'ldap1.miraheze.org' {
    include base
    include role::openldap
}

node 'mail1.miraheze.org' {
    include base
    include role::mail
    include role::roundcubemail
}

node 'misc1.miraheze.org' {
    include base
    include role::mail
    include prometheus::php_fpm
}

node 'mon1.miraheze.org' {
    include base
    include role::grafana
    include role::icinga2
    include role::irc
    include role::matomo
    include role::prometheus
    include prometheus::php_fpm
}

node /^mw[4567]\.miraheze\.org$/ {
    include base
    include role::mediawiki
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
    include prometheus::php_fpm
}

node 'puppet2.miraheze.org' {
    include base
    include bacula::client
    include role::postgresql
    include puppetdb::database
    include role::puppetserver
    include role::salt
}

node /^rdb[12]\.miraheze\.org$/ {
    include base
    include role::redis
    include prometheus::redis_exporter
}

node /^services[12]\.miraheze\.org$/ {
    include base
    include role::services
}

node 'test2.miraheze.org' {
    include base
    include role::mediawiki
    include prometheus::php_fpm
}

# ensures all servers have basic class if puppet runs
node default {
    include base
}
