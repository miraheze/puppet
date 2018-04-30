
class pdf::ganglia {
    file { '/usr/lib/ganglia/python_modules/ocg.py':
        ensure => absent,
    }
    file { '/etc/ganglia/conf.d/ocg.pyconf':
        ensure  => absent,
    }
}
