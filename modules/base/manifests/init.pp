# class: base
class base {
    include base::packages
    include base::monitoring
    include base::ufw
    include ssh
    include users

    cron { 'puppet-run-no-force':
        command => "/root/puppet-run &> /var/log/puppet-run.log",
        user    => 'root',
        minute  => [ 10, 20, 30, 40, 50 ],
    }

    cron { 'puppet-run-force':
        command => "/root/puppet-run -f &> /var/log/puppet-run.log",
        user    => 'root',
        hour    => '*',
        minute  => '0',
    }

    file { '/root/puppet-run':
        ensure => present,
        source => 'puppet:///modules/base/puppet/puppet-run',
        mode   => '0775',
    }

    file { 'etc/puppet/hiera.yaml':
        ensure => present,
        source => 'puppet:///modules/base/puppet/hiera.yaml',
        mode   => '0444',
    }

    file { '/etc/puppet/puppet.conf':
        ensure => present,
        source => 'puppet:///modules/base/puppet/puppet.conf',
        mode   => '0444',
    }

    file { '/etc/puppet/fileserver.conf':
        ensure => present,
        source => 'puppet:///modules/base/puppet/fileserver.conf',
        mode   => '0444',
    }

    if $::hostname != "misc1" {
        mailalias { 'root':
            recipient => 'root@miraheze.org',
        }
    }

    # SUDO FOR NRPE
    sudo::user { 'nrpe_sudo':
        user => 'nagios',
        privileges => [ 'ALL = NOPASSWD: /usr/lib/nagios/plugins/check_puppet_run', ],
    }
}
