# === Class mediawiki::firejail
#
# Firejail files for MediaWiki
class mediawiki::firejail {
    stdlib::ensure_packages('firejail')

    file { '/etc/firejail/mediawiki.local':
        source => 'puppet:///modules/mediawiki/firejail/firejail-mediawiki.profile',
        owner  => 'root',
        group  => 'root',
        mode   => '0444',
    }

    file { '/etc/firejail/mediawiki-converters.profile':
        source => 'puppet:///modules/mediawiki/firejail/mediawiki-converters.profile',
        owner  => 'root',
        group  => 'root',
        mode   => '0444',
    }

    file { '/usr/local/bin/mediawiki-firejail-espeak':
        source => 'puppet:///modules/mediawiki/firejail/mediawiki-firejail-espeak.sh',
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
    }

    file { '/usr/local/bin/mediawiki-firejail-ghostscript':
        source => 'puppet:///modules/mediawiki/firejail/mediawiki-firejail-ghostscript.sh',
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
    }

    file { '/usr/local/bin/mediawiki-firejail-lame':
        source => 'puppet:///modules/mediawiki/firejail/mediawiki-firejail-lame.sh',
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
    }

    file { '/usr/local/bin/mediawiki-firejail-magick':
        source => 'puppet:///modules/mediawiki/firejail/mediawiki-firejail-magick.sh',
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
    }

    file { '/usr/local/bin/rsvg-convert':
        source => 'puppet:///modules/mediawiki/firejail/mediawiki-firejail-rsvg-convert.sh',
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
    }
}
