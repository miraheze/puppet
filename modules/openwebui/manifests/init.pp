class openwebui (
    String $user = 'openwebui',
    String $group = 'openwebui',
    String $base_dir = '/opt/open-webui',
    String $venv_python = 'python3', # system python
    String $bind_host = '0.0.0.0',
    Integer $port = 3000,
    String $backend_api_base = 'http://127.0.0.1:11434/v1',
    String $backend_api_key = 'local-anything',
) {
    package { ['python3','python3-venv','python3-pip','git']:
        ensure => present,
    }


    group { $group:
        ensure => present,
        system => true,
    }


    user { $user:
        ensure => present,
        system => true,
        shell => '/usr/sbin/nologin',
        home => $base_dir,
        gid => $group,
    }


    file { $base_dir:
        ensure => directory,
        owner => $user,
        group => $group,
        mode => '0755',
    }


    exec { 'openwebui_venv_create':
        command => "${venv_python} -m venv ${base_dir}/venv",
        creates => "${base_dir}/venv/bin/activate",
        path => ['/usr/bin','/usr/sbin','/bin','/sbin'],
        require => File[$base_dir],
    }


    exec { 'openwebui_pip_install':
        command => "${base_dir}/venv/bin/pip install --upgrade pip && ${base_dir}/venv/bin/pip install open-webui",
        unless => "${base_dir}/venv/bin/pip show open-webui",
        path => ['/usr/bin','/usr/sbin','/bin','/sbin'],
        require => Exec['openwebui_venv_create'],
    }


    file { '/etc/openwebui.env':
        ensure => file,
        owner => 'root',
        group => 'root',
        mode => '0644',
        content => epp('open_webui/openwebui.env.epp', {
        'backend_api_base' => $backend_api_base,
        'backend_api_key' => $backend_api_key,
        'bind_host' => $bind_host,
        'port' => $port,
        }),
        notify => Exec['systemd-daemon-reload'],
    }


    file { '/etc/systemd/system/openwebui.service':
        ensure => file,
        owner => 'root',
        group => 'root',
        mode => '0644',
        content => epp('open_webui/openwebui.service.epp', {}),
        notify => Exec['systemd-daemon-reload'],
    }


    exec { 'systemd-daemon-reload':
        command => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }


    service { 'openwebui':
        ensure => running,
        enable => true,
        subscribe => [File['/etc/openwebui.env'], File['/etc/systemd/system/openwebui.service']],
    }
}
