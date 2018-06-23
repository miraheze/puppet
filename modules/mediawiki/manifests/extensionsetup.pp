# MediaWiki extension setup
class mediawiki::extensionsetup {
    exec { 'Math texvccheck':
        command => '/usr/bin/make --directory=/srv/mediawiki/w/extensions/Math/texvccheck',
        creates => '/srv/mediawiki/w/extensions/Math/texvccheck/texvccheck',
        require => [ Git::Clone['MediaWiki core'], Package['ocaml'] ],
    }

    exec { 'wikibase_composer':
        command     => 'curl -sS https://getcomposer.org/installer | php && php composer.phar install',
        creates     => '/srv/mediawiki/w/extensions/Wikibase/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/Wikibase',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/Wikibase',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'maps_composer':
        command     => 'curl -sS https://getcomposer.org/installer | php && php composer.phar install',
        creates     => '/srv/mediawiki/w/extensions/Maps/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/Maps',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/Maps',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'flow_composer':
        command     => 'curl -sS https://getcomposer.org/installer | php && php composer.phar install',
        creates     => '/srv/mediawiki/w/extensions/Flow/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/Flow',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/Flow',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'cookiewarning_composer':
        command     => 'curl -sS https://getcomposer.org/installer | php && php composer.phar install',
        creates     => '/srv/mediawiki/w/extensions/CookieWarning/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/CookieWarning',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/CookieWarning',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'syntaxhighlight_geshi_composer':
        command     => 'curl -sS https://getcomposer.org/installer | php && php composer.phar install',
        creates     => '/srv/mediawiki/w/extensions/SyntaxHighlight_GeSHi/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/SyntaxHighlight_GeSHi',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/SyntaxHighlight_GeSHi',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'oauth_composer':
        command     => 'curl -sS https://getcomposer.org/installer | php && php composer.phar install',
        creates     => '/srv/mediawiki/w/extensions/OAuth/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/OAuth',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/OAuth',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'templatestyles_composer':
        command     => 'curl -sS https://getcomposer.org/installer | php && php composer.phar install',
        creates     => '/srv/mediawiki/w/extensions/TemplateStyles/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/TemplateStyles',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/TemplateStyles',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'antispoof_composer':
        command     => 'curl -sS https://getcomposer.org/installer | php && php composer.phar install',
        creates     => '/srv/mediawiki/w/extensions/AntiSpoof/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/AntiSpoof',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/AntiSpoof',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'kartographer_composer':
        command     => 'curl -sS https://getcomposer.org/installer | php && php composer.phar install',
        creates     => '/srv/mediawiki/w/extensions/Kartographer/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/Kartographer',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/Kartographer',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'timedmediahandler_composer':
        command     => 'curl -sS https://getcomposer.org/installer | php && php composer.phar install',
        creates     => '/srv/mediawiki/w/extensions/TimedMediaHandler/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/TimedMediaHandler',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/TimedMediaHandler',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'translate_composer':
        command     => 'curl -sS https://getcomposer.org/installer | php && php composer.phar install',
        creates     => '/srv/mediawiki/w/extensions/Translate/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/Translate',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/Translate',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
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
