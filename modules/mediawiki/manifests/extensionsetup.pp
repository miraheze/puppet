# MediaWiki extension setup
class mediawiki::extensionsetup {
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

    exec { 'install_composer':
        command     => 'wget -O /usr/bin/composer https://getcomposer.org/download/2.1.6/composer.phar && chmod 0755 /usr/bin/composer',
        creates     => '/usr/bin/composer',
        path        => '/usr/bin',
        user        => 'root',
    }

    $composer = 'composer install --no-dev'

    exec { 'wikibase_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/Wikibase/vendor",
        cwd         => "${mwpath}/extensions/Wikibase",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/Wikibase",
        user        => 'www-data',
        require     => [ Git::Clone['MediaWiki core'], Exec['install_composer'] ],
    }

    exec { 'maps_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/Maps/vendor",
        cwd         => "${mwpath}/extensions/Maps",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/Maps",
        user        => 'www-data',
        require     => [ Git::Clone['MediaWiki core'], Exec['install_composer'] ],
    }

    exec { 'flow_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/Flow/vendor",
        cwd         => "${mwpath}/extensions/Flow",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/Flow",
        user        => 'www-data',
        require     => [ Git::Clone['MediaWiki core'], Exec['install_composer'] ],
    }

    exec { 'oauth_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/OAuth/vendor",
        cwd         => "${mwpath}/extensions/OAuth",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/OAuth",
        user        => 'www-data',
        require     => [ Git::Clone['MediaWiki core'], Exec['install_composer'] ],
    }

    exec { 'templatestyles_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/TemplateStyles/vendor",
        cwd         => "${mwpath}/extensions/TemplateStyles",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/TemplateStyles",
        user        => 'www-data',
        require     => [ Git::Clone['MediaWiki core'], Exec['install_composer'] ],
    }

    exec { 'antispoof_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/AntiSpoof/vendor",
        cwd         => "${mwpath}extensions/AntiSpoof",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/AntiSpoof",
        user        => 'www-data',
        require     => [ Git::Clone['MediaWiki core'], Exec['install_composer'] ],
    }

    exec { 'kartographer_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/Kartographer/vendor",
        cwd         => "${mwpath}/extensions/Kartographer",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/Kartographer",
        user        => 'www-data',
        require     => [ Git::Clone['MediaWiki core'], Exec['install_composer'] ],
    }

    exec { 'timedmediahandler_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/TimedMediaHandler/vendor",
        cwd         => "${mwpath}/extensions/TimedMediaHandler",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/TimedMediaHandler",
        user        => 'www-data',
        require     => [ Git::Clone['MediaWiki core'], Exec['install_composer'] ],
    }

    exec { 'translate_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/Translate/vendor",
        cwd         => "${mwpath}/extensions/Translate",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/Translate",
        user        => 'www-data',
        require     => [ Git::Clone['MediaWiki core'], Exec['install_composer'] ],
    }

    exec { 'oathauth_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/OATHAuth/vendor",
        cwd         => "${mwpath}/extensions/OATHAuth",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/OATHAuth",
        user        => 'www-data',
        require     => [ Git::Clone['MediaWiki core'], Exec['install_composer'] ],
    }
    
    exec { 'lingo_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/Lingo/vendor",
        cwd         => "${mwpath}/extensions/Lingo",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/Lingo",
        user        => 'www-data',
        require     => [ Git::Clone['MediaWiki core'], Exec['install_composer'] ],
    }

    exec { 'wikibasequalityconstraints_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/WikibaseQualityConstraints/vendor",
        cwd         => "${mwpath}/extensions/WikibaseQualityConstraints",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/WikibaseQualityConstraints",
        user        => 'www-data',
        require     => [ Git::Clone['MediaWiki core'], Exec['install_composer'] ],
    }

    exec { 'wikibaselexeme_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/WikibaseLexeme/vendor",
        cwd         => "${mwpath}/extensions/WikibaseLexeme",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/WikibaseLexeme",
        user        => 'www-data',
        require     => [ Git::Clone['MediaWiki core'], Exec['install_composer'] ],
    }

    exec { 'createwiki_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/CreateWiki/vendor",
        cwd         => "${mwpath}/extensions/CreateWiki",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/CreateWiki",
        user        => 'www-data',
        require     => [ Git::Clone['MediaWiki core'], Exec['install_composer'] ],
    }

    exec { 'datatransfer_composer':
        command     => 'composer require phpoffice/phpspreadsheet',
        creates     => "${mwpath}/extensions/DataTransfer/vendor",
        cwd         => "${mwpath}/extensions/DataTransfer",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/DataTransfer",
        user        => 'www-data',
        require     => [ Git::Clone['MediaWiki core'], Exec['install_composer'] ],
    }

    exec { 'bootstrap_composer':
        command     => $composer,
        creates     => "${mwpath}/extensions/Bootstrap/vendor",
        cwd         => "${mwpath}/extensions/Bootstrap",
        path        => '/usr/bin',
        environment => "HOME=${mwpath}/extensions/Bootstrap",
        user        => 'www-data',
        require     => [ Git::Clone['MediaWiki core'], Exec['install_composer'] ],
    }
}
