class parsoid {
    include apt

    apt::source { 'parsoid':
        location => 'http://parsoid.wmflabs.org:8080/deb',
        repos    => 'main',
    }

    package { 'parsoid':
        ensure  => present,
        require => Apt::Source['parsoid'],
    }

    service { 'parsoid':
        ensure    => running,
        require   => Package['parsoid'],
        subscribe => File['/etc/mediawiki/parsoid/settings.js'],
    }

    file { '/etc/mediawiki/parsoid/settings.js':
        ensure => present,
        source => 'puppet:///modules/parsoid/settings.js',
    }
}
