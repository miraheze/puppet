# === Define mediawiki::extensionsetup
define mediawiki::extensionsetup (
    String $branch,
    String $version,
) {
    stdlib::ensure_packages('composer')

    $mwpath = "/srv/mediawiki-staging/${version}"

    file { [
        "/srv/mediawiki/${version}/extensions/OAuth/.composer/cache",
        "/srv/mediawiki-staging/${version}/extensions/OAuth/.composer/cache",
        "/srv/mediawiki/${version}/extensions/OAuth/vendor/league/oauth2-server/.git",
        "/srv/mediawiki-staging/${version}/extensions/OAuth/vendor/league/oauth2-server/.git"]:
            ensure  => absent,
            force   => true,
            recurse => true,
            require => Exec["OAuth-${branch} composer"],
    }

    $repos = loadyaml('/etc/puppetlabs/puppet/mediawiki-repos/mediawiki-repos.yaml')

    $repos.each |$name, $params| {
        $should_install = $params['versions'] ? {
            undef   => true,
            default => $version in split($params['versions'], /,\s?/),
        }

        # lint:ignore:selector_inside_resource
        git::clone { "MediaWiki-${branch} ${name}":
            ensure             => $params['removed'] ? {
                true    => absent,
                default => $should_install ? {
                    true    => $params['latest'] ? {
                        true    => latest,
                        default => present,
                    },
                    default => absent,
                },
            },
            directory          => "${mwpath}/${params['path']}",
            origin             => $params['repo_url'],
            branch             => $params['branch'] ? {
                '_branch_' => $branch == 'master' ? {
                    true    => $params['alpha_branch'] ? {
                        undef   => $branch,
                        default => $params['alpha_branch'],
                    },
                    default => $branch,
                },
                default    => $params['branch'],
            },
            owner              => 'www-data',
            group              => 'www-data',
            mode               => '0755',
            depth              => '5',
            recurse_submodules => true,
            shallow_submodules => $params['shallow_submodules'] ? {
                true    => true,
                default => false,
            },
            require            => Git::Clone["MediaWiki-${branch} core"],
        }
        # lint:endignore

        if $should_install {
            if $params['composer'] {
                exec { "${name}-${branch} composer":
                    command     => 'composer install --no-dev',
                    creates     => "${mwpath}/${params['path']}/vendor",
                    cwd         => "${mwpath}/${params['path']}",
                    path        => '/usr/bin',
                    environment => [
                        "HOME=${mwpath}/${params['path']}",
                        'HTTP_PROXY=http://bast.miraheze.org:8080'
                    ],
                    user        => 'www-data',
                    require     => Git::Clone["MediaWiki-${branch} ${name}"],
                }
            }

            if $params['latest'] {
                exec { "MediaWiki-${branch} ${name} Sync":
                    command     => "/usr/local/bin/mwdeploy --folders=${version}/${params['path']} --servers=${lookup(mediawiki::default_sync)}",
                    cwd         => '/srv/mediawiki-staging',
                    refreshonly => true,
                    user        => 'www-data',
                    subscribe   => Git::Clone["MediaWiki-${branch} ${name}"],
                    require     => File['/usr/local/bin/mwdeploy'],
                }
            }
        }
    }

    file { "${mwpath}/composer.local.json":
        ensure  => present,
        owner   => 'www-data',
        group   => 'www-data',
        mode    => '0664',
        source  => 'puppet:///mediawiki-repos/composer.local.json',
        require => Git::Clone["MediaWiki-${branch} core"],
    }
}
