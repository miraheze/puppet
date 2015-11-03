# Define ufw::logging
define ufw::logging(
    $level='low',
) {
    exec { "ufw-logging-${level}":
        command  => "ufw logging ${level}",
        unless   => "grep -qE '^LOGLEVEL=${level}$' /etc/ufw/ufw.conf",
        path     => '/usr/sbin:/bin:/usr/bin',
        provider => 'posix',
        require  => Exec['ufw-default-deny'],
        before   => Exec['ufw-enable'],
    }
}
