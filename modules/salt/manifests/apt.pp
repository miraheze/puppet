class apt {
    include ::apt

    if !defined(Apt::Source['salt_apt']) {
        apt::key { 'salt_key':
          id     => '126C0D24BD8A2942CC7DF8AC7638D0442B90D010',
          source => 'https://repo.saltstack.com/apt/debian/9/amd64/2018.3/SALTSTACK-GPG-KEY.pub',
        }

        apt::source { 'salt_apt':
          location => 'http://repo.saltstack.com/apt/debian/9/amd64/2018.3',
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
