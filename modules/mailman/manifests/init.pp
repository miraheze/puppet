# class: mailman
class mailman (
    $modules = ['alias', 'headers', 'rewrite', 'proxy', 'proxy_http', 'proxy_uwsgi', 'ssl'],
    $mailman_hyperkitty_api_key = hiera('mailman_hyperkitty_api_key'),
    $mailman3_web_secret_key = hiera('mailman3_web_secret_key'),
    $mailman3_rest_api_pass = hiera('mailman3_rest_api_pass'),
    $mailman3_admin_pass = hiera('mailman3_admin_pass'),
    $noreply_password = hiera('passwords::mail::noreply'),
) {
    include ::httpd

    include ssl::wildcard

    require_package(['libapache2-mod-uwsgi', 'libapache2-mod-proxy-uwsgi'])

    httpd::site { 'mailman.miraheze.org':
        ensure  => present,
        source  => 'puppet:///modules/mailman3/apache/apache.conf',
        monitor => true,
    }

    httpd::mod { 'mailman3_apache':
        modules => $modules,
        require => [
            Package['libapache2-mod-uwsgi'],
            Package['libapache2-mod-proxy-uwsgi']
        ],
    }

    apt::pin { 'debian_stretch_backports':
        priority   => 740,
        originator => 'Debian',
        release    => 'stretch-backports',
        packages   => 'mailman3-full',
    }

    package { 'mailman3-full':
        ensure => installed,
        require => File['/etc/apt/preferences'],
    }

    file { '/etc/mailman3/mailman-hyperkitty.cfg':
        ensure  => present,
        content => template('mailman3/mailman-hyperkitty.cfg.erb'),
        owner   => 'root',
        group   => 'list',
        notify  => Service['mailman3'],
        require => Package['mailman3-full'],
    }

    file { '/etc/mailman3/mailman-web.py':
        ensure  => present,
        content => template('mailman3/mailman-web.py.erb'),
        owner   => 'root',
        group   => 'www-data',
        notify  => Service['mailman3-web'],
        require => Package['mailman3-full'],
    }

    file { '/etc/mailman3/mailman.cfg':
        ensure  => present,
        content => template('mailman3/mailman.cfg.erb'),
        owner   => 'root',
        group   => 'list',
        notify  => Service['mailman3'],
        require => Package['mailman3-full'],
    }

    file { '/etc/mailman3/uwsgi.ini':
        ensure  => present,
        content => template('mailman3/uwsgi.ini.erb'),
        owner   => 'root',
        group   => 'root',
        notify  => Service['mailman3-web'],
        require => Package['mailman3-full'],
    }

    service { 'mailman3':
        ensure    => running,
        hasstatus => true,
        subscribe => File['/etc/mailman3/mm_cfg.py'],
    }

    service { 'mailman3-web':
        ensure    => running,
        hasstatus => true,
        subscribe => File['/etc/mailman3/mm_cfg.py'],
    }
}
