# servers

node 'bacula2.miraheze.org' {
    include base
    include bacula::director
}

node /^cloud[12345]\.miraheze\.org$/ {
    include base
    include role::cloud
}

node /^cp([3679]|1[012])\.miraheze\.org$/ {
    include base
    include role::varnish
}

node 'db9.miraheze.org' {
    include base
    include role::db
    include bacula::client
    include prometheus::mysqld_exporter
}

node /^db1[123]\.miraheze\.org$/ {
    include base
    include role::db
    include bacula::client
    include prometheus::mysqld_exporter
}

node 'dbbackup1.miraheze.org' {
    include base
    include role::dbreplication
}

node /^gluster[1234]\.miraheze\.org$/ {
    include base
    include bacula::client
    include role::gluster
}

node 'glustermigrtemp1.miraheze.org' {
    include base

    include ssl::wildcard

    gluster::mount { '/mnt/mediawiki-static':
      ensure    => mounted,
      volume    => lookup('gluster_volume', {'default_value' => 'gluster1.miraheze.org:/mvol'}),
    }
}

node 'graylog1.miraheze.org' {
    include base
    include role::graylog
}

node /^jobrunner[13]\.miraheze.org$/ {
    include base
    include role::redis
    include role::mediawiki
    include prometheus::redis_exporter
}

node /^jobrunner[24]\.miraheze.org$/ {
    include base
    include role::mediawiki
}

node 'ldap1.miraheze.org' {
    include base
    include role::openldap
}

node 'ldap2.miraheze.org' {
    include base
    include role::openldap
}

node 'mail1.miraheze.org' {
    include base
    include role::mail
    include role::roundcubemail
}

node 'mail2.miraheze.org' {
    include base
    include role::mail
    include role::roundcubemail
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

node 'mon2.miraheze.org' {
    include base
    include role::grafana
    include role::icinga2
    include role::irc
    include role::matomo
    include role::prometheus
    include prometheus::php_fpm
}

node /^mw([4567]|10|11)\.miraheze\.org$/ {
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

node 'phab2.miraheze.org' {
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

node 'puppet3.miraheze.org' {
    include base
    include bacula::client
    include role::postgresql
    include puppetdb::database
    include role::puppetserver
    include role::salt
}

node /^rdb[1234]\.miraheze\.org$/ {
    include base
    include role::redis
    include prometheus::redis_exporter
}

node /^services[124]\.miraheze\.org$/ {
    include base
    include role::services
}

node 'test2.miraheze.org' {
    include base
    include role::mediawiki
    include prometheus::php_fpm
}

node 'test3.miraheze.org' {
    include base
    include role::mediawiki
    include prometheus::php_fpm
}

# ensures all servers have basic class if puppet runs
node default {
    include base
}
