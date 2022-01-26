# class: mailman
class mailman (
    String $modules = ['alias', 'headers', 'rewrite', 'proxy', 'proxy_http', 'proxy_uwsgi', 'ssl'],
    String $mailman_hyperkitty_api_key = lookup('mailman_hyperkitty_api_key'),
    String $mailman3_web_secret_key = lookup('mailman3_web_secret_key'),
    String $mailman3_rest_api_pass = lookup('mailman3_rest_api_pass'),
    String $mailman3_admin_pass = lookup('mailman3_admin_pass'),
    String $noreply_password = lookup('passwords::mail::noreply'),
) {
    include ::httpd

    include ssl::wildcard

    ensure_packages(['libapache2-mod-uwsgi', 'libapache2-mod-proxy-uwsgi'])

    httpd::site { 'mailman.miraheze.org':
        ensure  => present,
        source  => 'puppet:///modules/mailman/apache/apache.conf',
        monitor => true,
    }

    httpd::mod { 'mailman3_apache':
        modules => $modules,
        require => [
            Package['libapache2-mod-uwsgi'],
            Package['libapache2-mod-proxy-uwsgi']
        ],
    }

    apt::pin { 'mailman3_debian_stretch_backports':
        priority   => 740,
        originator => 'Debian',
        release    => 'stretch-backports',
        packages   => 'mailman3-full',
    }
    
    require_package(['python-pymysql', 'python-mysqldb'])

    package { 'mailman3-full':
        ensure          => installed,
        install_options => ['-t', 'stretch-backports'],
        require         => File['/etc/apt/preferences'],
    }

    file { '/etc/mailman3':
        ensure => directory,
        owner   => 'root',
        group   => 'root',
    }

    file { '/etc/mailman3/mailman-hyperkitty.cfg':
        ensure  => present,
        content => template('mailman/mailman-hyperkitty.cfg.erb'),
        owner   => 'root',
        group   => 'list',
        notify  => Service['mailman3'],
        require => File['/etc/mailman3'],
    }

    file { '/etc/mailman3/mailman-web.py':
        ensure  => present,
        content => template('mailman/mailman-web.py.erb'),
        owner   => 'root',
        group   => 'www-data',
        notify  => Service['mailman3-web'],
        require => File['/etc/mailman3'],
    }

    file { '/etc/mailman3/mailman.cfg':
        ensure  => present,
        content => template('mailman/mailman.cfg.erb'),
        owner   => 'root',
        group   => 'list',
        notify  => Service['mailman3'],
        require => File['/etc/mailman3'],
    }

    file { '/etc/mailman3/uwsgi.ini':
        ensure  => present,
        content => template('mailman/uwsgi.ini.erb'),
        owner   => 'root',
        group   => 'root',
        notify  => Service['mailman3-web'],
        require => File['/etc/mailman3'],
    }

    service { 'mailman3':
        ensure    => running,
        require   => Package['mailman3-full'],
    }

    service { 'mailman3-web':
        ensure    => running,
        require   => Package['mailman3-full'],
    }
}
