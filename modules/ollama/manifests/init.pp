# ollama
class ollama (
    String $group = 'ollama',
    String $home = '/usr/share/ollama',
    String $install_script_url = 'https://ollama.com/install.sh',
    String $service_envfile = '/etc/ollama.conf',
    String $bind_host = '0.0.0.0', # API bind; 127.0.0.1 for local-only
    String $allowed_origins = '*', # tighten for prod
) {
    package { ['curl','gnupg','python3','python3-venv','git']:
        ensure => present,
    }

    group { $group:
        ensure => present,
        system => true,
    }

    user { $user:
        ensure => present,
        system => true,
        shell  => '/usr/sbin/nologin',
        home   => $home,
        gid    => $group,
    }

    file { $home:
        ensure => directory,
        owner  => $user,
        group  => $group,
        mode   => '0755',
    }

    # Install Ollama from official script (idempotent w/creates)
    exec { 'ollama_install':
        command => "curl -fsSL ${install_script_url} | sh",
        creates => '/usr/bin/ollama',
        path    => ['/usr/bin','/usr/sbin','/bin','/sbin'],
        timeout => 0,
    }

    file { $service_envfile:
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => "OLLAMA_HOST=${bind_host}\nOLLAMA_ORIGINS=${allowed_origins}\n",
        notify  => Exec['systemd-daemon-reload'],
    }

    file { '/etc/systemd/system/ollama.service':
        ensure    => file,
        owner     => 'root',
        group     => 'root',
        mode      => '0644',
        content   => epp('ollama/ollama.service.epp', {
        'user'    => $user,
        'group'   => $group,
        'envfile' => $service_envfile,
        }),
        notify => Exec['systemd-daemon-reload'],
    }

    exec { 'systemd-daemon-reload':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }

    service { 'ollama':
        ensure    => running,
        enable    => true,
        subscribe => [File[$service_envfile], File['/etc/systemd/system/ollama.service']],
        require   => Exec['ollama_install'],
    }
}
