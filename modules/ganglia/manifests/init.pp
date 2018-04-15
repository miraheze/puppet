# class: ganglia
class ganglia(
    # use php7 on stretch+
    $modules = ['rewrite', 'ssl', 'php5']
) {
    include ::httpd

    include ssl::wildcard

    $packages = [
        'rrdtool',
        'gmetad',
        'ganglia-webfrontend',
    ]

    package { $packages:
        ensure => present,
    }

    if os_version('debian >= stretch') {
        $php_version = '7.0'
    } else {
        $php_version = '5'
    }

    require_package("libapache2-mod-php${php_version}")

    file { '/etc/ganglia/gmetad.conf':
        ensure => present,
        source => 'puppet:///modules/ganglia/gmetad.conf',
    }

    file { '/etc/apache2/sites-enabled/apache.conf':
        ensure => absent,
    }

    httpd::site { 'ganglia.miraheze.org':
        ensure  => present,
        source  => 'puppet:///modules/ganglia/apache/apache.conf',
        require => File['/etc/apache2/sites-enabled/apache.conf'],
        monitor => true,
    }

    if os_version('debian >= stretch') {
        file { "/etc/php/${php_version}/apache2/conf.d/php.ini":
            ensure  => present,
            mode    => '0755',
            source  => 'puppet:///modules/ganglia/apache/php7.ini',
            require => Package['libapache2-mod-php${$php_version}']
        }
    } else {
        file { '/etc/php5/apache2/php.ini':
            ensure  => present,
            mode    => '0755',
            source  => 'puppet:///modules/ganglia/apache/php.ini',
            require => Package["libapache2-mod-php${$php_version}"]
        }
    }

    httpd::mod { 'ganglia_apache':
        modules => $modules,
        require => Package["libapache2-mod-php${php_version}"],
    }
}
