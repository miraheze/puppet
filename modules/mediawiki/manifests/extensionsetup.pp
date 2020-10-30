# MediaWiki extension setup
class mediawiki::extensionsetup {
    $composer = 'wget -O composer.phar https://getcomposer.org/composer-1.phar | php && php composer.phar install --no-dev'
    exec { 'wikibase_composer':
        command     => $composer,
        creates     => '/srv/mediawiki/w/extensions/Wikibase/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/Wikibase',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/Wikibase',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'maps_composer':
        command     => $composer,
        creates     => '/srv/mediawiki/w/extensions/Maps/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/Maps',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/Maps',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'flow_composer':
        command     => $composer,
        creates     => '/srv/mediawiki/w/extensions/Flow/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/Flow',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/Flow',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'cookiewarning_composer':
        command     => "${composer} && php composer.phar require geoip2/geoip2",
        creates     => '/srv/mediawiki/w/extensions/CookieWarning/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/CookieWarning',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/CookieWarning',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'syntaxhighlight_geshi_composer':
        command     => $composer,
        creates     => '/srv/mediawiki/w/extensions/SyntaxHighlight_GeSHi/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/SyntaxHighlight_GeSHi',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/SyntaxHighlight_GeSHi',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'oauth_composer':
        command     => $composer,
        creates     => '/srv/mediawiki/w/extensions/OAuth/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/OAuth',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/OAuth',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'templatestyles_composer':
        command     => $composer,
        creates     => '/srv/mediawiki/w/extensions/TemplateStyles/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/TemplateStyles',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/TemplateStyles',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'antispoof_composer':
        command     => $composer,
        creates     => '/srv/mediawiki/w/extensions/AntiSpoof/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/AntiSpoof',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/AntiSpoof',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'kartographer_composer':
        command     => $composer,
        creates     => '/srv/mediawiki/w/extensions/Kartographer/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/Kartographer',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/Kartographer',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'timedmediahandler_composer':
        command     => $composer,
        creates     => '/srv/mediawiki/w/extensions/TimedMediaHandler/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/TimedMediaHandler',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/TimedMediaHandler',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'translate_composer':
        command     => $composer,
        creates     => '/srv/mediawiki/w/extensions/Translate/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/Translate',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/Translate',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'oathauth_composer':
        command     => $composer,
        creates     => '/srv/mediawiki/w/extensions/OATHAuth/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/OATHAuth',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/OATHAuth/Widgets',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }
    
    exec { 'bootstrap_composer':
        command     => $composer,
        creates     => '/srv/mediawiki/w/extensions/Bootstrap/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/Bootstrap',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/Bootstrap',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }


    exec { 'widgets_composer':
        command     => $composer,
        creates     => '/srv/mediawiki/w/extensions/Widgets/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/Widgets',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/Widgets',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'mermaid_composer':
        command     => $composer,
        creates     => '/srv/mediawiki/w/extensions/Mermaid/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/Mermaid',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/Mermaid',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }
    
    exec { 'lingo_composer':
        command     => $composer,
        creates     => '/srv/mediawiki/w/extensions/Lingo/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/Lingo',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/Lingo',
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
