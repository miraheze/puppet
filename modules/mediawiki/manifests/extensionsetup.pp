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
    
    exec { 'lingo_composer':
        command     => $composer,
        creates     => '/srv/mediawiki/w/extensions/Lingo/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/Lingo',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/Lingo',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'wikibasequalityconstraints_composer':
        command     => $composer,
        creates     => '/srv/mediawiki/w/extensions/WikibaseQualityConstraints/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/WikibaseQualityConstraints',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/WikibaseQualityConstraints',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'wikibaselexeme_composer':
        command     => $composer,
        creates     => '/srv/mediawiki/w/extensions/WikibaseLexeme/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/WikibaseLexeme',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/WikibaseLexeme',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'createwiki_composer':
        command     => $composer,
        creates     => '/srv/mediawiki/w/extensions/CreateWiki/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/CreateWiki',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/CreateWiki',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }
    exec { 'datatransfer_composer':
        command     => "wget -O composer.phar https://getcomposer.org/composer-1.phar | php && php composer.phar require phpoffice/phpspreadsheet",
        creates     => '/srv/mediawiki/w/extensions/DataTransfer/composer.phar',
        cwd         => '/srv/mediawiki/w/extensions/DataTransfer',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/w/extensions/DataTransfer',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }
}
