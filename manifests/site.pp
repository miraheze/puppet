# servers

node /^bast1[02]1\.miraheze\.org$/ {
    include base
    include role::bastion
}

node /^cloud1[012]\.miraheze\.org$/ {
    include base
    include role::cloud
}

node /^cp(2[01]|3[01])\.miraheze\.org$/ {
    include base
    include role::varnish
}

node /^db1([012]1|12)\.miraheze\.org$/ {
    include base
    include role::db
}

node /^es1[012]1\.miraheze\.org$/ {
    include base
    include role::elasticsearch
}

node /^gluster1[012]1\.miraheze\.org$/ {
    include base
    include role::gluster
}

node 'graylog121.miraheze.org' {
    include base
    include role::graylog
}

node 'jobchron121.miraheze.org' {
    include base
    include role::redis
    include mediawiki::jobqueue::chron
}

node 'ldap111.miraheze.org' {
    include base
    include role::openldap
}

node 'mail121.miraheze.org' {
    include base
    include role::mail
    include role::roundcubemail
}

node 'matomo101.miraheze.org' {
    include base
    include role::matomo
}

node /^mem1[02]1\.miraheze\.org$/ {
    include base
    include role::memcached
}

node 'mon111.miraheze.org' {
    include base
    include role::grafana
    include role::icinga2
    include role::irc
}

node /^mw1[012][12]\.miraheze\.org$/ {
    include base
    include role::mediawiki
}

node 'mwtask111.miraheze.org' {
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

node 'prometheus101.miraheze.org' {
    include base
    include role::prometheus
}

node 'puppet111.miraheze.org' {
    include base
    include role::postgresql
    include puppetdb::database
    include role::puppetserver
    include role::salt
    include role::ssl
}

node 'reports121.miraheze.org' {
    include base
    include role::reports
}

node 'test101.miraheze.org' {
    include base
    include role::mediawiki
    include role::redis
    include mediawiki::jobqueue::chron
}

# ensures all servers have basic class if puppet runs
node default {
    include base
}
