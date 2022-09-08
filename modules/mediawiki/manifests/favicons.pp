# === Class mediawiki::favicons
class mediawiki::favicons {
    file { '/srv/mediawiki/favicons':
        ensure  => directory,
        owner   => 'www-data',
        group   => 'www-data',
        mode    => '0755',
        require => File['/srv/mediawiki'],
    }

    file { '/srv/mediawiki/favicons/default.ico':
        ensure  => present,
        source  => 'puppet:///modules/mediawiki/favicons/default.ico',
        require => File['/srv/mediawiki/favicons'],
    }

    file { '/srv/mediawiki/favicons/apple-touch-icon-default.png':
        ensure  => present,
        source  => 'puppet:///modules/mediawiki/favicons/apple-touch-icon-default.png',
        require => File['/srv/mediawiki/favicons'],
    }
}
