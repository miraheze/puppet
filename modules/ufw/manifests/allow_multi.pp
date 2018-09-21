# ufw::allow_multi
define ufw::allow_multi(
    String $proto = 'tcp',
    String $port = 'all',
    String $ip = '',
    Array[String] $from_array = ['any'],
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
