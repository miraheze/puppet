# == Class: puppetserver::puppetdb::client
#
# Configures a puppetserver to work as a puppetdb client
#
# === Parameters
#
# [*puppetdb_hostname*] The hostname for the puppetdb server, eg puppet141.miraheze.org
#
class puppetserver::puppetdb::client(
    String $puppetdb_hostname,
) {

    file { '/etc/puppetlabs/puppet/puppetdb.conf':
        ensure  => present,
        content => template('puppetserver/puppetdb.conf.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
    }

    file { '/etc/puppetlabs/puppet/routes.yaml':
        ensure => present,
        owner  => 'root',
        group  => 'root',
        mode   => '0444',
        source => 'puppet:///modules/puppetserver/routes.yaml',
    }

    if defined(Service['puppetserver']) {
        File['/etc/puppetlabs/puppet/routes.yaml'] -> Service['puppetserver']
    }

    # Absence of this directory causes the puppetserver to spit out
    # 'Removing mount "facts": /var/lib/puppet/facts does not exist or is not a directory'
    # and catalog compilation to fail with https://tickets.puppetlabs.com/browse/PDB-949
    file { '/opt/puppetlabs/puppet/facts':
        ensure => directory,
    }

    class { 'puppetdb': }

    $syslog_daemon = lookup('base::syslog::syslog_daemon', {'default_value' => 'syslog_ng'})
    if $syslog_daemon == 'syslog_ng' {
        puppetserver::logging { 'puppetdb':
            file_path           => '/etc/puppetlabs/puppetdb/logback.xml',
            file_source         => 'puppet:///modules/puppetserver/puppetdb_logback.xml',
            file_source_options => [
                '/var/log/puppetlabs/puppetdb/puppetdb.log.json',
                { 'flags' => 'no-parse' }
            ],
            program_name        => 'puppetdb',
            notify              => Service['puppetdb'],
        }
    } else {
        file { '/etc/puppetlabs/puppetdb/logback.xml':
            ensure => present,
            source => 'puppet:///modules/puppetserver/puppetdb_logback.xml',
            notify => Service['puppetdb'],
        }

        rsyslog::input::file { 'puppetdb':
            path              => '/var/log/puppetlabs/puppetdb/puppetdb.log.json',
            syslog_tag_prefix => '',
            use_udp           => true,
        }
    }
}
