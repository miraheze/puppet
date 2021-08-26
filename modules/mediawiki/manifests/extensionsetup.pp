# MediaWiki extension setup
class mediawiki::extensionsetup {
    if lookup(mediawiki::use_staging) {
        $mwpath = '/srv/mediawiki-staging/w/'
        file { [
        '/srv/mediawiki/w/extensions/OAuth/.composer/cache',
        '/srv/mediawiki-staging/w/extensions/OAuth/.composer/cache',
        '/srv/mediawiki/w/extensions/OAuth/vendor/league/oauth2-server/.git',
        '/srv/mediawiki-staging/w/extensions/OAuth/vendor/league/oauth2-server/.git']:
            ensure  => absent,
            force   => true,
            recurse => true,
            require => Exec['oauth_composer'],
        }
    } else {
        $mwpath = '/srv/mediawiki/w/'
    }
    $composer = 'composer install --no-dev'
    exec { 'wikibase_composer':
        command     => $composer,
        onlyif      => "[ ! -d "vendor" ]",
        cwd         => "${mwpath}extensions/Wikibase",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/Wikibase",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'maps_composer':
        command     => $composer,
        onlyif      => "[ ! -d "vendor" ]",
        cwd         => "${mwpath}/extensions/Maps",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/Maps",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'flow_composer':
        command     => $composer,
        onlyif      => "[ ! -d "vendor" ]",
        cwd         => "${mwpath}extensions/Flow",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/Flow",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'oauth_composer':
        command     => $composer,
        onlyif      => "[ ! -d "vendor" ]",
        cwd         => "${mwpath}extensions/OAuth",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/OAuth",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'templatestyles_composer':
        command     => $composer,
        onlyif      => "[ ! -d "vendor" ]",
        cwd         => "${mwpath}extensions/TemplateStyles",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/TemplateStyles",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'antispoof_composer':
        command     => $composer,
        onlyif      => "[ ! -d "vendor" ]",
        cwd         => "${mwpath}extensions/AntiSpoof",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/AntiSpoof",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'kartographer_composer':
        command     => $composer,
        onlyif      => "[ ! -d "vendor" ]",
        cwd         => "${mwpath}extensions/Kartographer",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/Kartographer",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'timedmediahandler_composer':
        command     => $composer,
        onlyif      => "[ ! -d "vendor" ]",
        cwd         => "${mwpath}extensions/TimedMediaHandler",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/TimedMediaHandler",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'translate_composer':
        command     => $composer,
        onlyif      => "[ ! -d "vendor" ]",
        cwd         => "${mwpath}extensions/Translate",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/Translate",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'oathauth_composer':
        command     => $composer,
        onlyif      => "[ ! -d "vendor" ]",
        cwd         => "${mwpath}extensions/OATHAuth",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/OATHAuth",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }
    
    exec { 'lingo_composer':
        command     => $composer,
        onlyif      => "[ ! -d "vendor" ]",
        cwd         => "${mwpath}extensions/Lingo",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/Lingo",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'wikibasequalityconstraints_composer':
        command     => $composer,
        onlyif      => "[ ! -d "vendor" ]",
        cwd         => "${mwpath}extensions/WikibaseQualityConstraints",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/WikibaseQualityConstraints",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'wikibaselexeme_composer':
        command     => $composer,
        onlyif      => "[ ! -d "vendor" ]",
        cwd         => "${mwpath}extensions/WikibaseLexeme",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/WikibaseLexeme",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'createwiki_composer':
        command     => $composer,
        onlyif      => "[ ! -d "vendor" ]",
        cwd         => "${mwpath}extensions/CreateWiki",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/CreateWiki",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'datatransfer_composer':
        command     => "composer require phpoffice/phpspreadsheet",
        onlyif      => "[ ! -d "vendor" ]",
        cwd         => "${mwpath}extensions/DataTransfer",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/DataTransfer",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'bootstrap_composer':
        command     => $composer,
        onlyif      => "[ ! -d "vendor" ]",
        cwd         => "${mwpath}extensions/Bootstrap",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}extensions/Bootstrap",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }
}
