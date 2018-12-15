# class: sudo::user
define sudo::user(
    Array $privileges,
    VMlib::Ensure $ensure  = present,
    String $user          = $title,
) {
    require sudo

    $title_safe = regsubst($title, '\W', '-', 'G')
    $filename = "/etc/sudoers.d/${title_safe}"

    if $ensure == 'present' {
        file { $filename:
            ensure  => $ensure,
            owner   => 'root',
            group   => 'root',
            mode    => '0440',
            content => template('sudo/sudoers.erb'),
        }

        exec { "sudo_user_${title}_linting":
            command     => "/bin/rm -f ${filename} && /bin/false",
            unless      => "/usr/sbin/visudo -cqf ${filename}",
            refreshonly => true,
            subscribe   => File[$filename],
        }
    } else {
        file { $filename:
            ensure => $ensure,
        }
    }
}
