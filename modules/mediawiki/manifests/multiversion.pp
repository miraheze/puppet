class mediawiki::multiversion (
    Hash $versions = lookup('mediawiki::multiversion::versions'),
) {
    file { '/srv/mediawiki/femiwiki-deploy':
        ensure => 'directory',
        owner  => 'www-data',
        group  => 'www-data',
    }

    file { '/srv/mediawiki/w':
        ensure  => 'link',
        target  => '/srv/mediawiki/config/initialise/entrypoints',
        owner   => 'www-data',
        group   => 'www-data',
        require => File['/srv/mediawiki/config'],
    }

    file { '/srv/mediawiki/index.php':
        ensure  => 'link',
        target  => '/srv/mediawiki/config/initialise/entrypoints/index.php',
        owner   => 'www-data',
        group   => 'www-data',
        require => File['/srv/mediawiki/config'],
    }

    if lookup(mediawiki::use_staging) {
        file { '/srv/mediawiki-staging/w':
            ensure  => 'link',
            target  => '/srv/mediawiki-staging/config/initialise/entrypoints',
            owner   => 'www-data',
            group   => 'www-data',
            require => File['/srv/mediawiki-staging/config'],
        }
    }

    $versions.each |$version, $params| {
        if lookup(mediawiki::use_staging) {
            mediawiki::extensionsetup { "MediaWiki-${version}":
                branch  => $params['branch'],
                version => $version,
            }

            git::clone { "MediaWiki-${params['branch']} core":
                ensure    => 'present',
                directory => "/srv/mediawiki-staging/${version}",
                origin    => 'https://github.com/wikimedia/mediawiki',
                branch    => $params['branch'],
                owner     => 'www-data',
                group     => 'www-data',
                mode      => '0755',
                timeout   => '1500',
                depth     => '5',
                require   => File['/srv/mediawiki-staging'],
            }
        }

        file { "/srv/mediawiki/${version}":
            ensure => 'directory',
            owner  => 'www-data',
            group  => 'www-data',
        }

        file { "/srv/mediawiki/cache/${version}":
            ensure => 'directory',
            owner  => 'www-data',
            group  => 'www-data',
        }

        git::clone { "femiwiki-deploy-${version}":
            ensure    => 'latest',
            directory => "/srv/mediawiki/femiwiki-deploy/${version}",
            origin    => 'https://github.com/miraheze/femiwiki-deploy',
            branch    => $params['branch'],
            owner     => 'www-data',
            group     => 'www-data',
            mode      => '0755',
            require   => File['/srv/mediawiki/femiwiki-deploy'],
        }

        file { "/srv/mediawiki/${version}/skins/Femiwiki/node_modules":
            ensure  => 'link',
            target  => "/srv/mediawiki/femiwiki-deploy/${version}/node_modules",
            owner   => 'www-data',
            group   => 'www-data',
            require => [
                Git::Clone["femiwiki-deploy-${version}"],
                File["/srv/mediawiki/${version}"],
            ],
        }

        file { "/srv/mediawiki/${version}/LocalSettings.php":
            ensure  => 'link',
            target  => '/srv/mediawiki/config/LocalSettings.php',
            owner   => 'www-data',
            group   => 'www-data',
            require => [
                File["/srv/mediawiki/${version}"],
                File['/srv/mediawiki/config'],
            ],
        }

        if (lookup(jobrunner) and $params['default']) {
            class { 'mediawiki::jobqueue::runner':
                version => $version,
            }

            if lookup('mwservices', {'default_value' => false}) {
                class { 'mediawiki::services_cron':
                    version => $version,
                }
            }
        }
    }
}
