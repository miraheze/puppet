# MediaWiki extension setup
class mediawiki::extensionsetup {
    if lookup(mediawiki::use_staging) {
        $mwpath = '/srv/mediawiki-staging/w/'
    } else {
        $mwpath = '/srv/mediawiki/w/'
    }
    $composer = 'wget -O composer.phar https://getcomposer.org/composer-1.phar | php && php composer.phar install --no-dev'
    exec { 'wikibase_composer':
        command     => $composer,
        creates     => "${mwpath}extensions/Wikibase/composer.phar",
        cwd         => "${mwpath}extensions/Wikibase",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/Wikibase",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'maps_composer':
        command     => $composer,
        creates     => "${mwpath}extensions/Maps/composer.phar",
        cwd         => "${mwpath}/extensions/Maps",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/Maps",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'flow_composer':
        command     => $composer,
        creates     => "${mwpath}extensions/Flow/composer.phar",
        cwd         => "${mwpath}extensions/Flow",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/Flow",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'oauth_composer':
        command     => $composer,
        creates     => "${mwpath}extensions/OAuth/composer.phar",
        cwd         => "${mwpath}extensions/OAuth",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/OAuth",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'templatestyles_composer':
        command     => $composer,
        creates     => "${mwpath}extensions/TemplateStyles/composer.phar",
        cwd         => "${mwpath}extensions/TemplateStyles",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/TemplateStyles",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'antispoof_composer':
        command     => $composer,
        creates     => "${mwpath}extensions/AntiSpoof/composer.phar",
        cwd         => "${mwpath}extensions/AntiSpoof",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/AntiSpoof",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'kartographer_composer':
        command     => $composer,
        creates     => "${mwpath}extensions/Kartographer/composer.phar",
        cwd         => "${mwpath}extensions/Kartographer",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/Kartographer",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'timedmediahandler_composer':
        command     => $composer,
        creates     => "${mwpath}extensions/TimedMediaHandler/composer.phar",
        cwd         => "${mwpath}extensions/TimedMediaHandler",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/TimedMediaHandler",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'translate_composer':
        command     => $composer,
        creates     => "${mwpath}extensions/Translate/composer.phar",
        cwd         => "${mwpath}extensions/Translate",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/Translate",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'oathauth_composer':
        command     => $composer,
        creates     => "${mwpath}extensions/OATHAuth/composer.phar",
        cwd         => "${mwpath}extensions/OATHAuth",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}OATHAuth/Widgets",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }
    
    exec { 'lingo_composer':
        command     => $composer,
        creates     => "${mwpath}extensions/Lingo/composer.phar",
        cwd         => "${mwpath}extensions/Lingo",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/Lingo",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'wikibasequalityconstraints_composer':
        command     => $composer,
        creates     => "${mwpath}extensions/WikibaseQualityConstraints/composer.phar",
        cwd         => "${mwpath}extensions/WikibaseQualityConstraints",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/WikibaseQualityConstraints",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'wikibaselexeme_composer':
        command     => $composer,
        creates     => "${mwpath}extensions/WikibaseLexeme/composer.phar",
        cwd         => "${mwpath}extensions/WikibaseLexeme",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/WikibaseLexeme",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'createwiki_composer':
        command     => $composer,
        creates     => "${mwpath}extensions/CreateWiki/composer.phar",
        cwd         => "${mwpath}extensions/CreateWiki",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/CreateWiki",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'datatransfer_composer':
        command     => "wget -O composer.phar https://getcomposer.org/composer-1.phar | php && php composer.phar require phpoffice/phpspreadsheet",
        creates     => "${mwpath}extensions/DataTransfer/composer.phar",
        cwd         => "${mwpath}extensions/DataTransfer",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/DataTransfer",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'bootstrap_composer':
        command     => $composer,
        creates     => "${mwpath}extensions/Bootstrap/composer.phar",
        cwd         => "${mwpath}extensions/Bootstrap",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/Bootstrap",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }
}
