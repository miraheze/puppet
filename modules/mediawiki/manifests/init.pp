# class: mediawiki
class mediawiki {
    file { [ '/srv/mediawiki', '/srv/mediawiki/dblist', '/srv/mediawiki-static', '/var/log/mediawiki' ]:
        ensure => 'directory',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0755',
    }

    file { '/etc/nginx/nginx.conf':
        content => template('mediawiki/nginx.conf.erb'),
    }

    package { 'imagemagick':
        ensure => present,
    }

    ssl::cert { 'wildcard.miraheze.org': }
    ssl::cert { 'spiral.wiki': }

    nginx::site { 'mediawiki':
        ensure   => present,
        source   => 'puppet:///modules/mediawiki/nginx/mediawiki.conf',
    }

    git::clone { 'MediaWiki config':
        directory => '/srv/mediawiki/config',
        origin    => 'https://github.com/miraheze/mw-config.git',
        ensure    => 'latest',
        require   => File['/srv/mediawiki'],
    }

    git::clone { 'MediaWiki core':
        directory           => '/srv/mediawiki/w',
        origin              => 'https://github.com/miraheze/mediawiki.git',
        branch              => 'REL1_25',
        ensure              => 'latest',
        timeout             => '550',
        recurse_submodules  => true,
        require             => File['/srv/mediawiki'],
    }

    git::clone { 'MediaWiki vendor':
        directory => '/srv/mediawiki/w/vendor',
        origin    => 'https://github.com/wikimedia/mediawiki-vendor.git',
        branch    => 'REL1_25',
        ensure    => 'latest',  
        require   => Git::Clone['MediaWiki core'],
    }

    file { '/srv/mediawiki/w/LocalSettings.php':
        ensure  => 'link',
        target  => '/srv/mediawiki/config/LocalSettings.php',
        require => Git::Clone['MediaWiki config'],
    }

    file { '/srv/mediawiki/config/PrivateSettings.php':
        ensure => 'present',
        source => 'puppet:///private/mediawiki/PrivateSettings.php',
    }

	file { '/usr/share/nginx/favicons':
        ensure  => 'directory',
        owner   => 'www-data',
        group   => 'www-data',
        mode    => 0755,
        require => Package['nginx'],
    }

	$favicons = [
		'default.ico',
		'spiral.wiki.ico'
	]
	
	file { "/usr/share/nginx/favicons/${favicons}":
		ensure	=> present,
		owner 	=> 'www-data',
		group	=> 'www-data',
		mode	=> 0644,
		source	=> "puppet:///modules/mediawiki/favicons/${favicons}",
	}
}
