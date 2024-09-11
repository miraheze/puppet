# === Class mediawiki::firejail
#
# Firejail files for MediaWiki
class mediawiki::firejail {
    stdlib::ensure_packages('firejail')

    file { '/usr/local/bin/mediawiki-firejail-convert':
        source => 'puppet:///modules/mediawiki/firejail/mediawiki-firejail-convert.sh',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0555',
    }

    file { '/etc/firejail/mediawiki.local':
        source => 'puppet:///modules/mediawiki/firejail/firejail-mediawiki.profile',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0644',
    }

    file { '/etc/firejail/mediawiki-converters.profile':
        source => 'puppet:///modules/mediawiki/firejail/mediawiki-converters.profile',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0644',
    }

    file { '/usr/local/bin/mediawiki-firejail-ghostscript':
        source => 'puppet:///modules/mediawiki/firejail/mediawiki-firejail-ghostscript.sh',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0555',
    }

    file { '/usr/local/bin/rsvg-convert':
        source => 'puppet:///modules/mediawiki/firejail/mediawiki-firejail-rsvg-convert.sh',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0555',
    }

    file { '/usr/local/bin/mediawiki-firejail-espeak':
        source => 'puppet:///modules/mediawiki/firejail/mediawiki-firejail-espeak.sh',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0555',
    }

    file { '/usr/local/bin/mediawiki-firejail-lame':
        source => 'puppet:///modules/mediawiki/firejail/mediawiki-firejail-lame.sh',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0555',
    }
}
