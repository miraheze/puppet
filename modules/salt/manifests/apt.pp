class salt::apt {
    include ::apt

    if !defined(Apt::Source['salt_apt']) {
        $os_version = $facts['os']['release']['major']
        apt::key { 'salt_key':
          id     => '754A1A7AE731F165D5E6D4BD0E08A149DE57BFBE',
          source => "https://repo.saltstack.com/py3/debian/${os_version}/amd64/3000/SALTSTACK-GPG-KEY.pub",
        }

        apt::source { 'salt_apt':
          location => "http://repo.saltstack.com/py3/debian/${os_version}/amd64/3000",
          release  => "${::lsbdistcodename}",
          repos    => 'main',
          notify   => Exec['apt_update_salt'],
        }

        # First installs can trip without this
        exec {'apt_update_salt':
            command     => '/usr/bin/apt-get update',
            refreshonly => true,
            logoutput   => true,
        }
    }
}
