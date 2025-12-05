# servers

node /^bast1[68]1\.wikitide\.net$/ {
    role(bastion)
}

node 'bots171.fsslc.wtnet' {
    role(irc)
}

node 'changeprop201.fsslc.wtnet' {
    include base
    include role::jobrunner_haproxy
    include role::changeprop
    include role::redis
}

node /^cloud[12][056789]\.wikitide\.net$/ {
    include base
    include role::cloud
}

node /^cloud[12][056789]\.fsslc\.wtnet$/ {
    include base
    include role::cloud
}

node 'cp161.wikitide.net' {
    include base
    include role::varnish
}

node /^cp([12][079]1)\.wikitide\.net$/ {
    role(cache::cache)
}

node /^db1([56789][12])\.fsslc\.wtnet$/ {
    include base
    include role::db
}

node /^db2([0][1])\.fsslc\.wtnet$/ {
    include base
    include role::db
}

node 'eventgate181.fsslc.wtnet' {
    include base
    include role::eventgate
}

node /^os[12][0569][12]\.fsslc\.wtnet$/ {
    include base
    include role::opensearch
}

node 'graylog161.fsslc.wtnet' {
    include base
    include role::graylog
}

node 'kafka181.fsslc.wtnet' {
    include base
    include role::kafka
    include role::burrow
}

node 'ldap171.fsslc.wtnet' {
    include base
    include role::openldap
}

node 'llm191.fsslc.wtnet' {
    include base
    include role::llm
}

node 'matomo151.fsslc.wtnet' {
    include base
    include role::matomo
}

node 'mattermost1.vps.wtnet' {
    include base
    include role::mattermost
}

node 'mattermost001.vps.wtnet' {
    include base
    include role::mattermost
}

node /^mem[12][0569]1\.fsslc\.wtnet$/ {
    include base
    include role::memcached
}

node 'mon181.fsslc.wtnet' {
    include base
    include role::grafana
    include role::icinga2
}

node /^mw[12][056789][1234]\.fsslc\.wtnet$/ {
    role(mediawiki)
}

node /^mwtask1[5678]1\.fsslc\.wtnet$/ {
    role(mediawiki_task)
}

node /^ns[12]\.wikitide\.net$/ {
    include base
    include role::dns
}

node /^dns(001|171)\.wikitide\.net$/ {
    include base
    include role::dns
}

node 'phorge171.fsslc.wtnet' {
    include base
    include role::phorge
}

node 'prometheus151.fsslc.wtnet' {
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

node 'rdb151.fsslc.wtnet' {
    include base
    include role::poolcounter
    include role::redis
}

node 'reports171.fsslc.wtnet' {
    include base
    include role::reports
}

node /^swiftproxy1[67]1\.fsslc\.wtnet$/ {
    include base
    include role::swift
}

node 'swiftac171.fsslc.wtnet' {
    include base
    include role::swift
}

node /^swiftobject[12][056789]1\.fsslc\.wtnet$/ {
    include base
    include role::swift
}

node 'test151.fsslc.wtnet' {
    role(mediawiki_beta)
}

# ensures all servers have basic class if puppet runs
node default {
    include base
}
