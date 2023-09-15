# servers

node /^bast1[24]1\.miraheze\.org$/ {
    include base
    include role::bastion
}

node /^cloud1[01234]\.miraheze\.org$/ {
    include base
    include role::cloud
}

node /^cp(2[2345]|3[23])\.miraheze\.org$/ {
    include base
    include role::varnish
}

node /^db1([0234][12]|12)\.miraheze\.org$/ {
    include base
    include role::db
}

node /^os1[34]1\.miraheze\.org$/ {
    include base
    include role::opensearch
}

node 'graylog131.miraheze.org' {
    include base
    include role::graylog
}

node 'jobchron121.miraheze.org' {
    include base
    include role::redis
    include mediawiki::jobqueue::chron
}

node 'ldap141.miraheze.org' {
    include base
    include role::openldap
}

node 'mail121.miraheze.org' {
    include base
    include role::mail
    include role::roundcubemail
}

node 'matomo121.miraheze.org' {
    include base
    include role::matomo
}

node /^mem1[34]1\.miraheze\.org$/ {
    include base
    include role::memcached
}

node 'mon141.miraheze.org' {
    include base
    include role::grafana
    include role::icinga2
    include role::irc
}

node /^mw1[234][1234]\.miraheze\.org$/ {
    include base
    include role::mediawiki
}

node 'mwtask141.miraheze.org' {
    include base
    include role::mediawiki
}

node /^ns[12]\.miraheze\.org$/ {
    include base
    include role::dns
}

node 'phab121.miraheze.org' {
    include base
    include role::phabricator
}

node 'prometheus131.miraheze.org' {
    include base
    include role::prometheus
}

node 'puppet141.miraheze.org' {
    include base
    include role::postgresql
    include puppetdb::database
    include role::puppetdb
    include role::puppetserver
    include role::salt
    include role::ssl
}

node 'puppetdb121.miraheze.org' {
    include base
    include role::postgresql
    include puppetdb::database
    include role::puppetdb
}

node 'reports121.miraheze.org' {
    include base
    include role::reports
}

node /^swiftproxy1[13]1\.miraheze\.org$/ {
    include base
    include role::swift
}

node 'swiftac111.miraheze.org' {
    include base
    include role::swift
}

node /^swiftobject1[012][123]\.miraheze\.org$/ {
    include base
    include role::swift
}

node 'test131.miraheze.org' {
    include base
    include role::memcached
    include role::mediawiki
    include role::redis
    include mediawiki::jobqueue::chron
}

# ensures all servers have basic class if puppet runs
node default {
    include base
}
