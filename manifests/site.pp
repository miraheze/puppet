# servers

node /^bast1[68]1\.wikitide\.net$/ {
    include base
    include role::bastion
}

node 'bots171.wikitide.net' {
    include base
    include role::irc
}

node /^cloud1[5678]\.wikitide\.net$/ {
    include base
    include role::cloud
}

node /^cp([23][678]|[45]1)\.wikitide\.net$/ {
    include base
    include role::varnish
}

node /^db1([5678][12])\.wikitide\.net$/ {
    include base
    include role::db
}

node /^os1[56][12]\.wikitide\.net$/ {
    include base
    include role::opensearch
}

node 'graylog161.wikitide.net' {
    include base
    include role::graylog
}

node 'jobchron171.wikitide.net' {
    include base
    include role::poolcounter
    include role::redis
    include mediawiki::jobqueue::chron
}

node 'ldap171.wikitide.net' {
    include base
    include role::openldap
}

node 'matomo151.wikitide.net' {
    include base
    include role::matomo
}

node /^mem1[56]1\.wikitide\.net$/ {
    include base
    include role::memcached
}

node 'mon181.wikitide.net' {
    include base
    include role::grafana
    include role::icinga2
}

node /^mw1[5678][12]\.wikitide\.net$/ {
    include base
    include role::mediawiki
}

node /^mwtask1[78]1\.wikitide\.net$/ {
    include base
    include role::mediawiki
    include role::mathoid
}

node /^ns[12]\.wikitide\.net$/ {
    include base
    include role::dns
}

node 'phorge171.wikitide.net' {
    include base
    include role::phorge
}

node 'prometheus151.wikitide.net' {
    include base
    include role::prometheus
}

node 'puppet181.wikitide.net' {
    include base
    include role::postgresql
    include puppetdb::database
    include role::puppetdb
    include role::puppetserver
    include role::salt
    include role::ssl
}

node 'rdb151.wikitide.net' {
    include base
    include role::redis
}

node 'reports171.wikitide.net' {
    include base
    include role::reports
}

node /^swiftproxy1[67]1\.wikitide\.net$/ {
    include base
    include role::swift
}

node 'swiftac171.wikitide.net' {
    include base
    include role::swift
}

node /^swiftobject1[5678]1\.wikitide\.net$/ {
    include base
    include role::swift
}

node 'test151.wikitide.net' {
    include base
    include role::memcached
    include role::mediawiki
    include role::poolcounter
    include role::redis
    include mediawiki::jobqueue::chron
}

# ensures all servers have basic class if puppet runs
node default {
    include base
}
