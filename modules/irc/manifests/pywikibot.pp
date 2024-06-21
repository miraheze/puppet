# class: irc::pywikibot
class irc::pywikibot {
    $install_path = '/srv/pywikibot'

    $consumer_token = lookup('passwords::pywikibot::consumer_token')
    $consumer_secret = lookup('passwords::pywikibot::consumer_secret')
    $access_token = lookup('passwords::pywikibot::access_token')
    $access_secret = lookup('passwords::pywikibot::access_secret')

    file { $install_path:
        ensure    => 'directory',
        owner     => 'irc',
        group     => 'irc',
        mode      => '0644',
        recurse   => true,
        max_files => 5000,
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
        ensure             => present,
        origin             => 'https://github.com/wikimedia/pywikibot',
        directory          => $install_path,
        owner              => 'irc',
        group              => 'irc',
        mode               => '0644',
        recurse_submodules => true,
        require            => File[$install_path],
    }

    file { "${install_path}/user-config.py":
        ensure  => present,
        owner   => 'irc',
        group   => 'irc',
        mode    => '0644',
        content => template('irc/pywikibot/user-config.py'),
        require => Git::Clone['PyWikiBot'],
    }

    file { "${install_path}/families/wikitide_family.py":
        ensure  => present,
        owner   => 'irc',
        group   => 'irc',
        mode    => '0644',
        content => template('irc/pywikibot/wikitide_family.py'),
        require => Git::Clone['PyWikiBot'],
    }

    cron { 'run pywikibot archivebot on meta':
        ensure  => present,
        command => '/usr/bin/python3 /srv/pywikibot/pwb.py archivebot Template:Autoarchive/config -pt:0 -dir:/srv/pywikibot >> /var/log/pwb-archivebot-cron.log 2>&1',
        user    => 'irc',
        minute  => '0',
        hour    => '0',
    }

    logrotate::rule { 'pwb-archivebot-cron':
        file_glob      => '/var/log/pwb-archivebot-cron.log',
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
