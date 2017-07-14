# class: ganglia
class ganglia {
    include ::apache::mod::php5
    include ::apache::mod::rewrite
    include ::apache::mod::ssl

    ssl::cert { 'wildcard.miraheze.org': }

    $packages = [
        'rrdtool',
        'gmetad',
        'ganglia-webfrontend',
    ]

    package { $packages:
        ensure => present,
    }

    file { '/etc/ganglia/gmetad.conf':
        ensure => present,
        source => 'puppet:///modules/ganglia/gmetad.conf',
    }

    file { '/etc/apache2/sites-enabled/apache.conf':
        ensure => absent,
    }

    apache::site { 'ganglia.miraheze.org':
        ensure  => present,
        source  => 'puppet:///modules/ganglia/apache/apache.conf',
        require => File['/etc/apache2/sites-enabled/apache.conf'],
    }

    file { '/etc/php5/apache2/php.ini':
        ensure => present,
        mode   => '0755',
        source => 'puppet:///modules/ganglia/apache/php.ini',
    }

}
