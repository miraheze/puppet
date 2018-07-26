# MediaWiki services setup
class mediawiki::servicessetup {
    include nodejs

    git::clone { 'mathoid':
        ensure    => present,
        directory => '/srv/mathoid',
        origin    => 'https://github.com/wikimedia/mathoid.git',
        branch    => 'master',
        owner     => 'root',
        group     => 'root',
        mode      => '0755',
    }

    exec { 'mathoid_npm':
        command     => 'sudo -u root npm install',
        creates     => '/srv/mediawiki/w/extensions/Wikibase/node_modules',
        cwd         => '/srv/mathoid',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mathoid',
        user        => 'root',
        require     => [Git::Clone['mathoid'], Package['nodejs'], Package['librsvg2-dev']],
    }
}
