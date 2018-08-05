# class: users::key
define users::key(
  $ensure  = present,
  $user    = $title,
  $skey    = undef,
  $source  = undef,
  $content = undef,

) {
    if $skey {
        if !defined(File["/etc/ssh/userkeys/${user}.d/"]) {
            file { "/etc/ssh/userkeys/${user}.d/":
                ensure => directory,
                force  => true,
                owner  => 'root',
                group  => 'root',
                mode   => '0755',
            }
        }
        $path = "/etc/ssh/userkeys/${user}.d/${skey}"
    } else {
        $path = "/etc/ssh/userkeys/${user}"
    }

    file { $path:
        ensure  => $ensure,
        force   => true,
        owner   => 'root',
        group   => 'root',
        mode    => '0444', # sshd drops perms before trying to read public keys
        content => $content,
        source  => $source,
    }
}
