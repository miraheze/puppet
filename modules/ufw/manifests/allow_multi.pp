# ufw::allow_multi
define ufw::allow_multi(
    $proto='tcp',
    $port='all',
    $ip='',
    $from_array=['any']
) {
    $from_array.each |String $from| {
        ufw::allow { "ufw allow from ${from} to ${port}":
            proto => $proto,
            port  => $port,
            ip    => $ip,
            from  => $from,
        }
    }
}
