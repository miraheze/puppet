# class: mediawiki::arcanist
#
# install arcanist on arcanist hosts (currently mw2 in hieradata)
class mediawiki::arcanist {
    file { '/srv/phab':
        ensure => directory,
    }

    git::clone { 'libphutil':
        ensure    => latest,
        directory => '/srv/phab/libphutil',
        origin    => 'https://github.com/phacility/libphutil.git',
        require   => File['/srv/phab'],
    }

    git::clone { 'arcanist':
        ensure    => latest,
        directory => '/srv/phab/arcanist',
        origin    => 'https://github.com/phacility/arcanist.git',
        require   => File['/srv/phab'],
    }
}
