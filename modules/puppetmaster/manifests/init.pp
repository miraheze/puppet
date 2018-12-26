# class: puppetmaster
class puppetmaster(
    Boolean $use_puppetdb          = hiera('puppetmaster::use_puppetdb', false),
    Array $modules                 = ['rewrite', 'ssl'],
    Integer $puppetmaster_version  = hiera('puppetmaster_version', 4),
    String $puppetmaster_hostname  = hiera('puppetmaster_hostname', 'puppet1.miraheze.org'),
    String $puppetserver_java_opts = hiera('puppetserver_java_opts', '-Xms150m -Xmx300m'),
) {

    if $puppetmaster_version == 6 {
        # TODO(paladox) move this back into init.pp
        class { '::puppetmaster::v6':
            puppetmaster_hostname  => $puppetmaster_hostname,
            puppetmaster_version   => $puppetmaster_version,
            use_puppetdb           => $use_puppetdb,
            puppetserver_java_opts => $puppetserver_java_opts,
        }
    } else {
        # deprecated
        include ::httpd

        $packages = [
            'libmariadbd-dev',
            'puppetmaster',
            'puppet-common',
            'puppetmaster-passenger',
        ]

        package { $packages:
            ensure => present,
        }

        $dbpassword = hiera('puppetmaster::dbpassword')

        file { '/etc/puppet/hiera.yaml':
            ensure  => present,
            source  => "puppet:///modules/puppetmaster/hiera.${puppetmaster_version}.yaml",
            require => Package['puppetmaster'],
            notify  => Service['apache2'],
        }

        file { '/etc/puppet/puppet.conf':
            ensure  => present,
            content => template("puppetmaster/puppet.${puppetmaster_version}.conf.erb"),
            require => Package['puppetmaster'],
            notify  => Service['apache2'],
        }

        file { '/etc/puppet/auth.conf':
            ensure  => present,
            source  => "puppet:///modules/puppetmaster/auth.${puppetmaster_version}.conf",
            require => Package['puppetmaster'],
            notify  => Service['apache2'],
        }

        file { '/etc/puppet/fileserver.conf':
            ensure  => present,
            source  => "puppet:///modules/puppetmaster/fileserver.${puppetmaster_version}.conf",
            require => Package['puppetmaster'],
            notify  => Service['apache2'],
        }

        git::clone { 'puppet':
            ensure    => latest,
            directory => '/etc/puppet/git',
            origin    => 'https://github.com/miraheze/puppet.git',
            require   => Package['puppetmaster'],
        }

        # work around for new puppet agent
        git::clone { 'services':
            ensure    => latest,
            directory => '/etc/puppet/services',
            origin    => 'https://github.com/miraheze/services.git',
            require   => Package['puppetmaster'],
        }

        git::clone { 'ssl':
            ensure    => latest,
            directory => '/etc/puppet/ssl',
            origin    => 'https://github.com/miraheze/ssl.git',
            require   => Package['puppetmaster'],
        }

        file { '/etc/puppet/private':
            ensure => directory,
        }

        file { '/etc/puppet/hieradata':
            ensure  => link,
            target  => '/etc/puppet/git/hieradata',
            require => Git::Clone['puppet'],
        }

        file { '/etc/puppet/manifests':
            ensure  => link,
            target  => '/etc/puppet/git/manifests',
            require => Git::Clone['puppet'],
        }

        file { '/etc/puppet/modules':
            ensure  => link,
            target  => '/etc/puppet/git/modules',
            require => Git::Clone['puppet'],
        }

        file { '/etc/puppet/environments':
            ensure  => directory,
            mode    => '0775',
            require => Package['puppetmaster'],
        }

        file { '/etc/puppet/environments/production':
            ensure  => directory,
            mode    => '0775',
            require => File['/etc/puppet/environments'],
        }

        file { '/etc/puppet/environments/production/manifests':
            ensure  => link,
            target  => '/etc/puppet/manifests',
            require => [File['/etc/puppet/environments/production'], File['/etc/puppet/manifests']],
        }

        file { '/etc/puppet/environments/production/modules':
            ensure  => link,
            target  => '/etc/puppet/modules',
            require => [File['/etc/puppet/environments/production'], File['/etc/puppet/modules']],
        }

        file { '/etc/puppet/environments/production/ssl':
            ensure  => link,
            target  => '/etc/puppet/ssl',
            require => [File['/etc/puppet/environments/production'], Git::Clone['ssl']],
        }

        file { '/home/puppet-users':
            ensure  => directory,
            owner   => 'root',
            group   => 'puppet-users',
            mode    => '0770',
        }

        if $use_puppetdb {
            class { 'puppetmaster::puppetdb::client': }
        }

        service { 'puppetmaster':
            ensure => stopped,
            before => Service['apache2'],
        }

        httpd::site { 'puppet-master':
            ensure => present,
            content => template("puppetmaster/puppet-master.conf.erb"),
            monitor => false,
        }

        # Place an empty puppet-master.conf file to prevent creation of this file
        # at package install time. Apache breaks if that happens. T179102
        file { '/etc/apache2/sites-available/puppet-master.conf':
            ensure  => present,
            content => '# This file intentionally left blank by puppet'
        }

        file { '/etc/apache2/sites-enabled/puppet-master.conf':
            ensure  => link,
            target  => '/etc/apache2/sites-available/puppet-master.conf',
            require => File['/etc/apache2/sites-available/puppet-master.conf'],
        }

        httpd::mod { 'puppetmaster_apache':
            modules => $modules,
        }

        ufw::allow { 'puppetmaster':
            proto => 'tcp',
            port  => '8140',
        }

        cron { 'puppet-git':
            command => '/usr/bin/git -C /etc/puppet/git pull',
            user    => 'root',
            hour    => '*',
            minute  => [ '9', '19', '29', '39', '49', '59' ],
        }

        cron { 'services-git':
            command => '/usr/bin/git -C /etc/puppet/services pull',
            user    => 'root',
            hour    => '*',
            minute  => [ '9', '19', '29', '39', '49', '59' ],
        }

        cron { 'ssl-git':
            command => '/usr/bin/git -C /etc/puppet/ssl pull',
            user    => 'root',
            hour    => '*',
            minute  => [ '9', '19', '29', '39', '49', '59' ],
        }

        cron { 'puppet-old-reports-remove':
            ensure  => present,
            command => 'find /var/lib/puppet/reports -type f -mmin +960 -delete >/dev/null 2>&1',
            user    => 'root',
            hour    => [ '0', '8', '16' ],
            minute  => [ '27' ],
        }
    }
}
