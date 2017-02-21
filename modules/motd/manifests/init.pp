# class: motd
class motd {
    file { '/etc/motd':
        ensure => link,
        target => '/var/run/motd',
        force  => true,
    }

    file { '/etc/update-motd.d':
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        recurse => true,
        purge   => true,
    }

    motd::script { 'header':
        ensure   => present,
        priority => 00,
        content  => "#!/bin/sh\nuname -snrvm\nlsb_release -s -d\n\n",
    }

    motd::script { 'footer':
        ensure   => present,
        priority => 99,
        content  => "#!/bin/sh\n[ -f /etc/motd.tail ] && cat /etc/motd.tail || true\n",
    }
}
