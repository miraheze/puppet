# === Class role::memcached
class role::memcached (
    String            $version          = lookup('role::memcached::version'),
    Stdlib::Port      $port             = lookup('role::memcached::port'),
    Integer           $size             = lookup('role::memcached::size'),
    Array[String]     $extended_options = lookup('role::memcached::extended_options'),
    Integer           $max_seq_reqs     = lookup('role::memcached::max_seq_reqs'),
    Integer           $min_slab_size    = lookup('role::memcached::min_slab_size'),
    Float             $growth_factor    = lookup('role::memcached::growth_factor'),
    Optional[Integer] $threads          = lookup('role::memcached::threads'),
) {
    include prometheus::memcached_exporter

    if !empty( $extended_options ) {
        $base_extra_options = {
            '-o' => join($extended_options, ','),
            '-D' => ':',
        }
    } else {
        $base_extra_options = {'-D' => ':'}
    }

    if $max_seq_reqs {
        $max_seq_reqs_opt = {'-R' => $max_seq_reqs}
    } else {
        $max_seq_reqs_opt = {}
    }

    if $threads {
        $threads_opt = {'-t' => $threads}
    } else {
        $threads_opt = {}
    }

    $extra_options = $base_extra_options + $max_seq_reqs_opt + $threads_opt

    class { '::memcached':
        size          => $size,
        port          => $port,
        version       => $version,
        growth_factor => $growth_factor,
        min_slab_size => $min_slab_size,
        extra_options => $extra_options,
    }

    $firewall_rules_str = join(
        query_facts('Class[Role::Mediawiki] or Class[Role::Icinga2]', ['ipaddress', 'ipaddress6'])
        .map |$key, $value| {
            "${value['ipaddress']} ${value['ipaddress6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'memcached':
        proto   => 'tcp',
        port    => $port,
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    motd::role { 'role::memcached':
        description => 'Memcached server',
    }
}
