# mediawiki::php7_2
class mediawiki::php7_2 {
    include ::apt

    if !defined(Apt::Source['php72_apt']) {
        apt::source { 'php72_apt':
            comment  => 'PHP 7.2',
            location => 'http://apt.wikimedia.org/wikimedia',
            release  => "${::lsbdistcodename}-wikimedia",
            repos    => 'thirdparty/php72',
            key      => 'B8A2DF05748F9D524A3A2ADE9D392D3FFADF18FB',
            notify   => Exec['apt_update_php'],
        }

        # First installs can trip without this
        exec {'apt_update_php':
            command     => '/usr/bin/apt-get update',
            refreshonly => true,
            logoutput   => true,
        }
    }

    $packages = [
        'php-mail',
        'php-luasandbox',
        'php7.2',
        'php7.2-curl',
        'php7.2-fpm',
        'php7.2-gd',
        'php7.2-intl',
        'php7.2-json',
        'php7.2-mbstring',
        'php7.2-mysql',
        'php7.2-mysqlnd',
    ]

    package { $packages:
        ensure  => present,
        require => Apt::Source['php72_apt'],
    }

    exec { "install_php_igbinary":
        command => '/usr/bin/curl -o /opt/php-igbinary_2.0.1-1%2B0~20170825111216.1%2Bstretch~1.gbp48b058_amd64.deb https://packages.sury.org/php/pool/main/p/php-igbinary/php-igbinary_2.0.1-1%2B0~20170825111216.1%2Bstretch~1.gbp48b058_amd64.deb',
        unless  => '/bin/ls /opt/php-igbinary_2.0.1-1%2B0~20170825111216.1%2Bstretch~1.gbp48b058_amd64.deb',
    }

    exec { "install_php_redis_7_2":
        command => '/usr/bin/curl -o /opt/php-redis_4.0.0-1%2B0~20180412074133.5%2Bstretch~1.gbp24a357_amd64.deb https://packages.sury.org/php/pool/main/p/php-redis/php-redis_4.0.0-1%2B0~20180412074133.5%2Bstretch~1.gbp24a357_amd64.deb',
        unless  => '/bin/ls /opt/php-redis_4.0.0-1%2B0~20180412074133.5%2Bstretch~1.gbp24a357_amd64.deb',
    }

    exec { "install_php_imagick":
        command => '/usr/bin/curl -o /opt/php-imagick_3.4.3-2%2B0~20170825111201.3%2Bstretch~1.gbp4fa216_amd64.deb https://packages.sury.org/php/pool/main/p/php-imagick/php-imagick_3.4.3-2%2B0~20170825111201.3%2Bstretch~1.gbp4fa216_amd64.deb',
        unless  => '/bin/ls /opt/php-redis_4.0.0-1%2B0~20180412074133.5%2Bstretch~1.gbp24a357_amd64.deb',
    }

    exec { "install_php_pear":
        command => '/usr/bin/curl -o /opt/php-pear_1.10.5%2Bsubmodules%2Bnotgz-1%2B0~20170904061717.3%2Bstretch~1.gbpe356ca_all.deb https://packages.sury.org/php/pool/main/p/php-pear/php-pear_1.10.5%2Bsubmodules%2Bnotgz-1%2B0~20170904061717.3%2Bstretch~1.gbpe356ca_all.deb',
        unless  => '/bin/ls /opt/php-pear_1.10.5%2Bsubmodules%2Bnotgz-1%2B0~20170904061717.3%2Bstretch~1.gbpe356ca_all.deb',
    }

    package { "php-igbinary":
        provider => dpkg,
        ensure   => present,
        source   => '/opt/php-igbinary_2.0.1-1%2B0~20170825111216.1%2Bstretch~1.gbp48b058_amd64.deb',
    }

    package { "php-redis":
        provider => dpkg,
        ensure   => present,
        source   => '/opt/php-redis_4.0.0-1%2B0~20180412074133.5%2Bstretch~1.gbp24a357_amd64.deb',
        require  => Package['php-igbinary'],
    }

    package { "php-imagick":
        provider => dpkg,
        ensure   => present,
        source   => '/opt/php-imagick_3.4.3-2%2B0~20170825111201.3%2Bstretch~1.gbp4fa216_amd64.deb',
    }

    package { "php-pear":
        provider => dpkg,
        ensure   => present,
        source   => '/opt/php-pear_1.10.5%2Bsubmodules%2Bnotgz-1%2B0~20170904061717.3%2Bstretch~1.gbpe356ca_all.deb',
    }

    service { 'php7.2-fpm':
        ensure  => running,
        require => Package['php7.2-fpm'],
    }

    file { '/etc/php/7.2/fpm/php-fpm.conf':
        ensure  => 'present',
        mode    => '0755',
        source  => 'puppet:///modules/mediawiki/php/php-fpm-7.2.conf',
        require => Package['php7.2-fpm'],
        notify  => Service['php7.2-fpm'],
    }

    file { '/etc/php/7.2/fpm/pool.d/www.conf':
        ensure  => 'present',
        mode    => '0755',
        source  => 'puppet:///modules/mediawiki/php/www-7.2.conf',
        require => Package['php7.2-fpm'],
        notify  => Service['php7.2-fpm'],
    }

    file { '/etc/php/7.2/fpm/php.ini':
        ensure  => present,
        mode    => '0755',
        source  => 'puppet:///modules/mediawiki/php/php-7.2.ini',
        require => Package['php7.2-fpm'],
        notify  => Service['php7.2-fpm'],
    }
}
