# servers

node 'bacula2.miraheze.org' {
    include base
    include bacula::director
}

node /^cloud[345]\.miraheze\.org$/ {
    include base
    include role::cloud
}

node /^cp(3|1[23])\.miraheze\.org$/ {
    include base
    include role::varnish
}

node /^db1[123]\.miraheze\.org$/ {
    include base
    include role::db
    include bacula::client
}

node 'dbbackup1.miraheze.org' {
    include base
    include role::dbbackup
}

node /^gluster[34]\.miraheze\.org$/ {
    include base
    include bacula::client
    include role::gluster
}

node 'graylog2.miraheze.org' {
    include base
    include role::graylog
}

node 'jobrunner3.miraheze.org' {
    include base
    include role::redis
    include role::mediawiki
    include prometheus::redis_exporter
}

node 'jobrunner4.miraheze.org' {
    include base
    include role::mediawiki
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

node /^mw([89]|1[01])\.miraheze\.org$/ {
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

node /^services[34]\.miraheze\.org$/ {
    include base
    include role::services
}

node 'test3.miraheze.org' {
    include base
    include role::mediawiki
    include prometheus::php_fpm
}

node 'test4.miraheze.org' {
    include base
    include role::trafficserver

    ufw::allow { 'http port 443 51.195.236.249':
        proto => 'tcp',
        port  => 443,
        from  => '51.195.236.249',
    }

    ufw::allow { 'https port 443 2001:41d0:800:1bbd::3':
        proto => 'tcp',
        port  => 443,
        from  => '2001:41d0:800:1bbd::3',
    }
}

# ensures all servers have basic class if puppet runs
node default {
    include base
}
