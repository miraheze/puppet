# class: varnish
class varnish {
    package { [ 'varnish', 'stunnel4' ]:
        ensure => present,
    }

    service { 'varnish':
        ensure  => 'running',
        require => Package['varnish'],
    }

    service { 'stunnel4':
        ensure  => 'running',
        require => Package['stunnel4'],
    }

    file { '/var/lib/varnish/mediawiki':
        ensure  => directory,
        notify  => Service['varnish'],
        require => Package['varnish'],
    }

    file { '/etc/varnish/default.vcl':
        ensure  => present,
        content => template('varnish/default.vcl'),
        notify  => Service['varnish'],
        require => Package['varnish'],
    }

    file { '/etc/default/varnish':
        ensure  => present,
        source  => 'puppet:///modules/varnish/varnish/varnish.default',
        notify  => Service['varnish'],
        require => Package['varnish'],
    }

    file { '/etc/systemd/system/varnish.service':
        ensure  => present,
        source  => 'puppet:///modules/varnish/varnish/varnish.service',
        require => Package['varnish'],
        notify  => Exec['systemctl daemon-reload'],
    }

    exec { 'systemctl daemon-reload':
        path        => '/bin',
        refreshonly => true,
    }

    ssl::cert { 'wildcard.miraheze.org': }
    ssl::cert { 'spiral.wiki': }
    ssl::cert { 'anuwiki.com': }
    ssl::cert { 'antiguabarbudacalypso.com': }
    ssl::cert { 'permanentfuturelab.wiki': }
    ssl::cert { 'secure.reviwiki.info': }
    ssl::cert { 'wiki.printmaking.be': }
    ssl::cert { 'private.revi.wiki': }
    ssl::cert { 'allthetropes.org': }
    ssl::cert { 'oneagencydunedin.wiki': }
    ssl::cert { 'publictestwiki.com': }
    ssl::cert { 'boulderwiki.org': }
    ssl::cert { 'wiki.zepaltusproject.com': }
    ssl::cert { 'universebuild.com': }
    ssl::cert { 'wiki.dottorconte.eu': }
    ssl::cert { 'wiki.valentinaproject.org': }

    nginx::site { 'mediawiki':
        ensure => present,
        source => 'puppet:///modules/varnish/nginx/mediawiki.conf',
    }

    file { '/etc/nginx/sites-enabled/default':
        ensure => absent,
        notify => Service['nginx'],
    }

    file { '/etc/nginx/nginx.conf':
        content => template('varnish/nginx.conf.erb'),
        notify  => Service['nginx'],
    }

    file { '/etc/default/stunnel4':
        ensure  => present,
        source  => 'puppet:///modules/varnish/stunnel/stunnel.default',
        notify  => Service['stunnel4'],
        require => Package['stunnel4'],
    }

    file { '/etc/stunnel/mediawiki.conf':
        ensure  => present,
        source  => 'puppet:///modules/varnish/stunnel/stunnel.conf',
        notify  => Service['stunnel4'],
        require => Package['stunnel4'],
    }

    file { '/usr/lib/nagios/plugins/check_varnishbackends':
        ensure  => present,
        source  => 'puppet:///modules/varnish/icinga/check_varnishbackends.py',
        mode    => 755,
    }

    # This script needs root access to read /etc/varnish/secret
    sudo::user { 'nrpe_sudo_checkvarnishbackends':
        user        => 'nagios',
        privileges  => [ 'ALL = NOPASSWD: /usr/lib/nagios/plugins/check_varnishbackends' ],
    }
}
