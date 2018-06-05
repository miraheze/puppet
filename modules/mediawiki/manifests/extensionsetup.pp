# MediaWiki extension setup
class mediawiki::extensionsetup {
    exec { 'mediawiki_core_composer':
        command     => 'curl -sS https://getcomposer.org/installer | php && php composer.phar install',
        creates     => '/srv/mediawiki/w/composer.phar',
        cwd         => '/srv/mediawiki/w',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'Math texvccheck':
        command => '/usr/bin/make --directory=/srv/mediawiki/w/extensions/Math/texvccheck',
        creates => '/srv/mediawiki/w/extensions/Math/texvccheck/texvccheck',
        require => [ Git::Clone['MediaWiki core'], Package['ocaml'] ],
    }

    # Ensure widgets template directory is read/writeable by webserver if mediawiki is cloned
    file { '/srv/mediawiki/w/extensions/Widgets/compiled_templates':
        ensure  => directory,
        owner   => 'www-data',
        group   => 'www-data',
        mode    => '0755',
        require => Git::Clone['MediaWiki core'],
    }
}
