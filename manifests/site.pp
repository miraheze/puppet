# servers

node /^bast1[68]1\.wikitide\.net$/ {
    role(bastion)
}

node 'bots171.wikitide.net' {
    role(irc)
}

node 'changeprop151.wikitide.net' {
    include base
    include role::jobrunner_haproxy
    include role::changeprop
    include role::redis
}

node 'changeprop201.wikitide.net' {
    include base
    include role::jobrunner_haproxy
    include role::changeprop
    include role::redis
}

node /^cloud[12][056789]\.wikitide\.net$/ {
    include base
    include role::cloud
}

node 'cp36.wikitide.net' {
    include base
    include role::varnish
}

node /^cp(3[78])\.wikitide\.net$/ {
    role(cache::cache)
}

node /^db1([5678][12])\.wikitide\.net$/ {
    include base
    include role::db
}

node 'eventgate181.wikitide.net' {
    include base
    include role::eventgate
}

node /^os1[56][12]\.wikitide\.net$/ {
    include base
    include role::opensearch
}

node 'graylog161.wikitide.net' {
    include base
    include role::graylog
}

node 'kafka181.wikitide.net' {
    include base
    include role::kafka
    include role::burrow
}

node 'ldap171.wikitide.net' {
    include base
    include role::openldap
}

node 'matomo151.wikitide.net' {
    include base
    include role::matomo
}

node 'mattermost1.wikitide.net' {
    include base
    include role::mattermost
}

node /^mem[12][056]1\.wikitide\.net$/ {
    include base
    include role::memcached
}

node 'mon181.wikitide.net' {
    include base
    include role::grafana
    include role::icinga2
}

node /^mw[12][056789][1234]\.wikitide\.net$/ {
    role(mediawiki)
}

node /^mwtask1[5678]1\.wikitide\.net$/ {
    role(mediawiki_task)
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
    include role::poolcounter
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

node /^swiftobject[12][056789]1\.wikitide\.net$/ {
    include base
    include role::swift
}

node 'test151.wikitide.net' {
    role(mediawiki_beta)
}

# ensures all servers have basic class if puppet runs
node default {
    include base
}
