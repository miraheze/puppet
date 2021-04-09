function trafficserver::get_paths() >> Hash {
    $libdir = '/usr/lib/trafficserver'
    $libexecdir = "${libdir}/modules"
    $secretsdir = "/run/trafficserver-secrets"
    $stekfile = "${secretsdir}/tickets.key"

    $base_path = undef
    $prefix = '/usr'
    $exec_prefix = $prefix
    $sysconfdir = '/etc/trafficserver'
    $datadir = '/var/cache/trafficserver'
    $localstatedir = '/run'
    $runtimedir = '/run/trafficserver'
    $logdir = '/var/log/trafficserver'

    $bindir = "${exec_prefix}/bin"
    $sbindir = "${exec_prefix}/sbin"
    $includedir = "${prefix}/include"
    $cachedir = $datadir

    $paths = {
        base_path     => $base_path,
        prefix        => $prefix,
        exec_prefix   => $exec_prefix,
        bindir        => $bindir,
        sbindir       => $sbindir,
        sysconfdir    => $sysconfdir,
        datadir       => $datadir,
        includedir    => $includedir,
        libdir        => $libdir,
        libexecdir    => $libexecdir,
        localstatedir => $localstatedir,
        runtimedir    => $runtimedir,
        logdir        => $logdir,
        cachedir      => $cachedir,
        records       => "${sysconfdir}/records.config",
        ssl_multicert => "${sysconfdir}/ssl_multicert.config",
        secretsdir    => $secretsdir,
        stekfile      => $stekfile,
    }
}
