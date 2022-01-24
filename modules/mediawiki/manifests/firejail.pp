# === Class mediawiki::firejail
#
# Firejail files for MediaWiki
class mediawiki::firejail {
    file { '/usr/local/bin/mediawiki-firejail-convert':
        source => 'puppet:///modules/mediawiki/mediawiki-firejail-convert.py',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0555',
    }

    file { '/etc/firejail/mediawiki.local':
        source => 'puppet:///modules/mediawiki/firejail-mediawiki.profile',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0644',
    }

    file { '/etc/firejail/mediawiki-converters.profile':
        source => 'puppet:///modules/mediawiki/mediawiki-converters.profile',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0644',
    }

    file { '/usr/local/bin/mediawiki-firejail-ghostscript':
        source => 'puppet:///modules/mediawiki/mediawiki-firejail-ghostscript.py',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0555',
    }
}
