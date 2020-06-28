# class: base::arcanist
#
# install arcanist on arcanist hosts (currently mw2 in hieradata)
class base::arcanist {
    file { '/srv/phab':
        ensure => directory,
    }

    git::clone { 'arcanist':
        ensure    => latest,
        directory => '/srv/phab/arcanist',
        origin    => 'https://github.com/phacility/arcanist.git',
        require   => File['/srv/phab'],
    }
}
