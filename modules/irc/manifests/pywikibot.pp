# class: irc::pywikibot
class irc::pywikibot {
    $install_path = '/srv/pywikibot'
    # The directory pointed to by the PYWIKIBOT_DIR environment variable
    $base_path = '/var/local/pwb'

    $consumer_token = lookup('passwords::pywikibot::consumer_token')
    $consumer_secret = lookup('passwords::pywikibot::consumer_secret')
    $access_token = lookup('passwords::pywikibot::access_token')
    $access_secret = lookup('passwords::pywikibot::access_secret')

    file { $install_path:
        ensure    => 'directory',
        owner     => 'irc',
        group     => 'irc',
        mode      => '0644',
        max_files => 5000,
    }

    file { $base_path:
        ensure => 'directory',
        owner  => 'irc',
        group  => 'irc',
        mode   => '0644',
    }

    file { "${base_path}/families":
        ensure => 'directory',
        owner  => 'irc',
        group  => 'irc',
        mode   => '0644',
    }

    file { '/usr/local/bin/pywikibot':
        ensure  => 'present',
        owner   => 'irc',
        group   => 'irc',
        mode    => '0555',
        content => template('irc/pywikibot/pywikibot.sh'),
    }

    file { '/var/log/pwb':
        ensure  => 'directory',
        owner   => 'irc',
        group   => 'irc',
        mode    => '0644',
        recurse => true,
    }

    stdlib::ensure_packages([
        'python3-mwparserfromhell',
        'python3-packaging',
        'python3-requests',
        'python3-mwoauth',
        'python3-pydot',
        'python3-stdnum',
        'python3-pil',
        'python3-mysqldb',
        'python3-bs4',
    ])

    git::clone { 'PyWikiBot':
        ensure             => latest,
        origin             => 'https://github.com/wikimedia/pywikibot',
        branch             => 'stable',
        directory          => $install_path,
        owner              => 'irc',
        group              => 'irc',
        recurse_submodules => true,
        require            => File[$install_path],
    }

    file { "${base_path}/user-config.py":
        ensure  => present,
        owner   => 'irc',
        group   => 'irc',
        mode    => '0400',
        content => template('irc/pywikibot/user-config.py'),
        require => Git::Clone['PyWikiBot'],
    }

    file { "${base_path}/families/wikitide_family.py":
        ensure  => present,
        owner   => 'irc',
        group   => 'irc',
        mode    => '0644',
        content => template('irc/pywikibot/wikitide_family.py'),
        require => Git::Clone['PyWikiBot'],
    }

    cron { 'run pywikibot archivebot on meta':
        ensure  => present,
        command => '/usr/local/bin/pywikibot archivebot Template:Autoarchive/config -pt:0 >> /var/log/pwb/archivebot-cron.log 2>&1',
        user    => 'irc',
        minute  => '0',
        hour    => '0',
    }

    logrotate::rule { 'pwb-archivebot-cron':
        file_glob      => '/var/log/pwb/archivebot-cron.log',
        frequency      => 'weekly',
        date_ext       => true,
        date_yesterday => true,
        copy_truncate  => true,
        rotate         => 7,
        missing_ok     => true,
        no_create      => true,
        compress       => true,
    }
}
