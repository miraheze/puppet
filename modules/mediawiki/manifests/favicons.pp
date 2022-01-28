# === Class mediawiki::favicons
class mediawiki::favicons {
    file { [
        '/usr/share/nginx',
        '/usr/share/nginx/favicons',
    ]:
        ensure => directory,
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0755',
    }

    file { '/usr/share/nginx/favicons/default.ico':
        ensure => present,
        source => 'puppet:///modules/mediawiki/favicons/default.ico',
    }

    file { '/usr/share/nginx/favicons/apple-touch-icon-default.png':
        ensure => present,
        source => 'puppet:///modules/mediawiki/favicons/apple-touch-icon-default.png',
    }
}
