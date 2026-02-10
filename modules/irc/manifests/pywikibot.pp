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
        owner     => 'pywikibot',
        group     => 'pywikibot',
        mode      => '0644',
        max_files => 5000,
    }

    file { $base_path:
        ensure => 'directory',
        owner  => 'pywikibot',
        group  => 'pywikibot',
        mode   => '0644',
    }

    file { "${base_path}/families":
        ensure => 'directory',
        owner  => 'pywikibot',
        group  => 'pywikibot',
        mode   => '0644',
    }

    file { '/usr/local/bin/pywikibot':
        ensure  => 'present',
        owner   => 'root',
        group   => 'root',
        mode    => '0555',
        content => template('irc/pywikibot/pywikibot.sh'),
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

    git::clone { 'Pywikibot-stable':
        ensure             => latest,
        origin             => 'https://github.com/wikimedia/pywikibot',
        branch             => 'stable',
        directory          => $install_path,
        owner              => 'pywikibot',
        group              => 'pywikibot',
        recurse_submodules => true,
        require            => File[$install_path],
    }

    file { "${base_path}/user-config.py":
        ensure  => present,
        owner   => 'pywikibot',
        group   => 'pywikibot',
        mode    => '0400',
        content => template('irc/pywikibot/user-config.py'),
        require => Git::Clone['Pywikibot-stable'],
    }

    $family_langs = loadyaml('/etc/puppetlabs/puppet/pywikibot-config/langs.yaml')

    file { "${base_path}/families/wikitide_family.py":
        ensure  => present,
        owner   => 'pywikibot',
        group   => 'pywikibot',
        mode    => '0644',
        content => template('irc/pywikibot/wikitide_family.py'),
        require => Git::Clone['Pywikibot-stable'],
    }

    $pwb_periodic_jobs = loadyaml('/etc/puppetlabs/puppet/pywikibot-config/periodic_jobs.yaml')
    $pwb_periodic_jobs.each |$dbname, $params| {
        $params.each |$script_config| {
            if $script_config['name'] == undef {
                warning("One periodic job entry for ${dbname} has no name attribute!")
                next()
            } elsif $script_config['script'] == undef {
                warning("One periodic job entry for ${dbname} has no script attribute!")
                next()
            } elsif $script_config['scriptparams'] == undef {
                warning("One periodic job entry for ${dbname} has no scriptparams attribute!")
                next()
            }
            $command = $script_config['scriptparams'] ? {
                '' => "/usr/local/bin/pywikibot ${script_config['script']} -lang:${dbname} -pt:0",
                default => "/usr/local/bin/pywikibot ${script_config['script']} ${script_config['scriptparams']} -lang:${dbname} -pt:0"
            }

            $minute = $script_config['minute'] ? {
                undef   => '0',
                default => $script_config['minute'],
            }

            $hour = $script_config['hour'] ? {
                undef   => '0',
                default => $script_config['hour'],
            }

            $monthday = $script_config['monthday'] ? {
                undef   => '*',
                default => $script_config['monthday'],
            }

            $month = $script_config['month'] ? {
                undef   => '*',
                default => $script_config['month'],
            }

            $weekday = $script_config['weekday'] ? {
                '*'     => '*-',
                undef   => '*-',
                default => "${script_config['weekday']} ",
            }

            $on_calendar = "${weekday}${month}-${monthday} ${hour}:${minute}:00"
            systemd::timer::job { "pywikibot-${dbname}-${script_config['name']}":
                ensure          => $script_config['ensure'],
                description     => "Runs pywikibot script ${script_config['name']} for ${dbname}",
                command         => $command,
                interval        => {
                    start    => 'OnCalendar',
                    interval => $on_calendar,
                },
                logfile_basedir => '/var/log/pwb',
                logfile_group   => 'pywikibot',
                user            => 'pywikibot',
            }
        }
    }
}
