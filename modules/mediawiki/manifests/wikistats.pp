# class mediawiki::wikistats
#
# Handles a few things to make wikistats work well with Miraheze
class mediawiki::wikistats {
    file { '/srv/mediawiki/wstats':
        ensure => directory,
        owner  => 'www-data',
        group  => 'www-data',
    }

    $customdomains = loadyaml('/etc/puppet/ssl/certs.yaml')
    file { '/srv/mediawiki/wstats/custom.txt':
        ensure  => present,
        owner   => 'www-data',
        group   => 'www-data',
        content => template('mediawiki/wikistats/custom.txt.erb'),
        require => File['/srv/mediawiki/wstats'],
    }

    file { '/usr/local/bin/wikistats-format-list.sh':
        ensure => present,
        mode   => '0775',
        source => 'puppet:///modules/mediawiki/wikistats/wikistats-format-list.sh',
    }

    cron { 'wikistats_all_wikis':
        ensure  => present,
        command => '/usr/local/bin/wikistats-format-list.sh /srv/mediawiki/dblist/all.dblist > /srv/mediawiki/wstats/miraheze.txt',
        user    => 'www-data',
        minute  => '0',
        hour    => '0',
        weekday => '*',
    }
}
