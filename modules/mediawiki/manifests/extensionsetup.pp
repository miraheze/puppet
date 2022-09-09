# === Class mediawiki::extensionsetup
class mediawiki::extensionsetup {
    ensure_packages('composer')

    $mwpath = '/srv/mediawiki-staging/w'
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

    $composer = 'composer install --no-dev'

    exec { 'wikibase_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/Wikibase/vendor",
        cwd         => "${mwpath}/extensions/Wikibase",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/Wikibase",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'maps_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/Maps/vendor",
        cwd         => "${mwpath}/extensions/Maps",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/Maps",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'flow_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/Flow/vendor",
        cwd         => "${mwpath}/extensions/Flow",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/Flow",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }
    exec { 'ipinfo_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/IPInfo/vendor",
        cwd         => "${mwpath}/extensions/IPInfo",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/IPInfo",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'oauth_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/OAuth/vendor",
        cwd         => "${mwpath}/extensions/OAuth",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/OAuth",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'templatestyles_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/TemplateStyles/vendor",
        cwd         => "${mwpath}/extensions/TemplateStyles",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/TemplateStyles",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'antispoof_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/AntiSpoof/vendor",
        cwd         => "${mwpath}/extensions/AntiSpoof",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/AntiSpoof",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'kartographer_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/Kartographer/vendor",
        cwd         => "${mwpath}/extensions/Kartographer",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/Kartographer",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'timedmediahandler_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/TimedMediaHandler/vendor",
        cwd         => "${mwpath}/extensions/TimedMediaHandler",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/TimedMediaHandler",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'translate_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/Translate/vendor",
        cwd         => "${mwpath}/extensions/Translate",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/Translate",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'oathauth_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/OATHAuth/vendor",
        cwd         => "${mwpath}/extensions/OATHAuth",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/OATHAuth",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'lingo_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/Lingo/vendor",
        cwd         => "${mwpath}/extensions/Lingo",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/Lingo",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'wikibasequalityconstraints_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/WikibaseQualityConstraints/vendor",
        cwd         => "${mwpath}/extensions/WikibaseQualityConstraints",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/WikibaseQualityConstraints",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'wikibaselexeme_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/WikibaseLexeme/vendor",
        cwd         => "${mwpath}/extensions/WikibaseLexeme",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/WikibaseLexeme",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'createwiki_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/CreateWiki/vendor",
        cwd         => "${mwpath}/extensions/CreateWiki",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/CreateWiki",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'datatransfer_composer':
        command     => 'composer require phpoffice/phpspreadsheet',
        creates     => "${mwpath}/extensions/DataTransfer/vendor",
        cwd         => "${mwpath}/extensions/DataTransfer",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/DataTransfer",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'bootstrap_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/Bootstrap/vendor",
        cwd         => "${mwpath}/extensions/Bootstrap",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/Bootstrap",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'structurednavigation_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/StructuredNavigation/vendor",
        cwd         => "${mwpath}/extensions/StructuredNavigation",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/StructuredNavigation",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'semanticmediawiki_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/SemanticMediaWiki/vendor",
        cwd         => "${mwpath}/extensions/SemanticMediaWiki",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/SemanticMediaWiki",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    exec { 'chameleon_composer':
        command     => 'composer require jeroen/file-fetcher',
        creates     => "${mwpath}/skins/chameleon/vendor",
        cwd         => "${mwpath}/skins/chameleon",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/skins/chameleon",
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }
}
