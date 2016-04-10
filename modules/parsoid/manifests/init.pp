class parsoid {
    include apt

    apt::source { 'parsoid':
        location => 'http://releases.wikimedia.org/debian',
        release  => 'jessie-mediawiki',
        repos    => 'main',
        key      => {
            'id'     => 'BE0C9EFB1A948BF3C8157E8B811780265C927F7C',
            'server' => 'hkp://keyserver.ubuntu.com:80',
        },
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

    # The name of the wiki (or the URL in form <wikiname>.miraheze.org. DO NOT INCLUDE WIKI.
    $wikis = [
                '8station',
                'adnovum',
                'air',
                'aktpos',
                'applebranch',
                'aryaman',
                'bgo',
                'biblicalwiki',
                'braindump',
                'carving',
                'cbmedia',
                'chandrusweths',
                'christipedia',
                'clementsworldbuilding',
                'clicordi',
                'cssandjsschoolboard',
                'development',
                'dicfic',
                'dmw',
                'drunkenpeasantswiki',
                'elainarmua',
                'extload',
                'ernaehrungsrathh',
                'essway',
                'etpo',
                'foodsharinghamburg',
                'games',
                'gen',
                'hftqms',
                'hobbies',
                'hshsinfoportal',
                'islamwissenschaft',
                'izanagi',
                'lbsges',
                'lclwiki',
                'littlebigplanet',
                'luckandlogic',
                'mecanon',
                'meta',
                'ndtest',
                'newtrend',
                'nidda23',
                'nwp',
                'partup',
                'pflanzen',
                'pq',
                'rawdata',
                'recherchesdocumentaires',
                'ric',
                'safiria',
                'shopping',
                'soshomophobie',
                'stellachronica',
                'sirikot',
                'taylor',
                'teleswiki',
                'test',
                'tochki',
                'torejorg',
                'unikum',
                'urho3d',
                'vrgo',
                'walthamstowlabour',
                'webflow',
    ]

    file { '/etc/mediawiki/parsoid/settings.js':
        ensure  => present,
        content => template('parsoid/settings.js'),
    }
}
