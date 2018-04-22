# class: php
class php {
    if os_version('debian >= stretch') {
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

        $php_packages = [
            'php-apcu',
            'php-mailparse',
            'php7.2-mysql',
            'php7.2-gd',
            'php7.2-gettext',
            'php7.2-dev',
            'php7.2-curl',
            'php7.2-cli',
            'php7.2-json',
            'php7.2-mbstring',
            'php7.2-xml',
        ]

        package { $php_packages:
            ensure => present,
            require => Apt::Source['php72_apt'],
        }
    } else {
        $php_packages = [
            'php5-apcu',
            'php5-mysqlnd',
            'php5-gd',
            'php5-dev',
            'php5-curl',
            'php5-cli',
            'php5-json',
        ]

        package { $php_packages:
            ensure => present;
        }
    }
}
