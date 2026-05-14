class mediawiki::global_rename_bot {
    $bot_password = lookup('passwords::mediawiki::global_rename_bot')

    $bot_dir = '/usr/local/lib/global_rename_bot'
    $log_dir = '/var/log/global_rename_bot'
    $etc_dir = '/etc/global_rename_bot'
    $user    = 'global_rename_bot'

    user { $user:
        ensure => present,
        home   => $bot_dir,
        shell  => '/usr/sbin/nologin',
        system => true,
    }

    file { [$bot_dir, $log_dir, $etc_dir]:
        ensure  => directory,
        owner   => $user,
        group   => $user,
        mode    => '0750',
        require => User[$user],
    }

    file { "${etc_dir}/password":
        ensure    => file,
        owner     => $user,
        group     => $user,
        mode      => '0400',
        content   => $bot_password,
        show_diff => false,
        require   => File[$etc_dir],
    }

    ['global_rename_bot.py', 'policy_checker.py', 'config.json'].each |String $f| {
        file { "${bot_dir}/${f}":
            ensure  => file,
            owner   => $user,
            group   => $user,
            mode    => '0550',
            source  => "puppet:///modules/mediawiki/bots/${f}",
            require => File[$bot_dir],
        }
    }

    package { ['python3-requests', 'python3-bs4']:
        ensure => present,
    }

    cron { 'global_rename_bot':
        ensure  => present,
        command => "cd ${bot_dir} && python3 global_rename_bot.py",
        user    => $user,
        minute  => '*/5',
        require => [
            File["${bot_dir}/global_rename_bot.py"],
            File["${bot_dir}/policy_checker.py"],
            File["${bot_dir}/config.json"],
            File["${etc_dir}/password"],
            Package['python3-requests'],
            Package['python3-bs4'],
        ],
    }
}
