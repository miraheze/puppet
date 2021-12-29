# servers

node 'bacula2.miraheze.org' {
    include base
    include bacula::director
}

node /^cloud[345]\.miraheze\.org$/ {
    include base
    include role::cloud
}

node /^cp(2[01]|3[01])\.miraheze\.org$/ {
    include base
    include role::varnish
}

node /^db1[123]\.miraheze\.org$/ {
    include base
    include role::db
    include bacula::client
}

node /^gluster[34]\.miraheze\.org$/ {
    include base
    include bacula::client
    include role::gluster
}

node 'graylog2.miraheze.org' {
    include base
    include role::graylog
    include prometheus::es_exporter
}

node 'jobchron1.miraheze.org' {
    include base
    include role::redis
    include prometheus::redis_exporter
    include mediawiki::jobqueue::chron
}

node 'ldap2.miraheze.org' {
    include base
    include role::openldap
}

node 'mail2.miraheze.org' {
    include base
    include role::mail
    include role::roundcubemail
}

node /^mem[12]\.miraheze\.org$/ {
    include base
    include role::memcached
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

node /^mw([89]|1[0123])\.miraheze\.org$/ {
    include base
    include role::mediawiki
    include prometheus::php_fpm
}

# new hardware
node /^mw(1[012][12])\.miraheze\.org$/ {
    include base
    include role::mediawiki
    include prometheus::php_fpm
}

node 'mwtask(1|101).miraheze.org' {
    include base
    include role::mediawiki
    include prometheus::php_fpm
}

node /^ns[12]\.miraheze\.org$/ {
    include base
    include role::dns
}

node 'phab2.miraheze.org' {
    include base
    include bacula::client
    include role::phabricator
    include prometheus::php_fpm
}

node 'puppet3.miraheze.org' {
    include base
    include bacula::client
    include role::postgresql
    include puppetdb::database
    include role::puppetserver
    include role::salt
}

node /^test(3|111).miraheze.org$/ {
    include base
    include role::mediawiki
    include prometheus::php_fpm
}

# ensures all servers have basic class if puppet runs
node default {
    include base
}
