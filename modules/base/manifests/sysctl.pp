class base::sysctl {
    sysctl::parameters { 'network adjustments':
        values   => {
            # Increase TCP max buffer size
            'net.core.rmem_max'                => 16777216, # default already
            'net.core.wmem_max'                => 16777216, # default already

            # Increase Linux auto-tuning TCP buffer limits
            # Values represent min, default, & max num. of bytes to use.
            'net.ipv4.tcp_rmem'                => [ 4096, 87380, 16777216 ],
            'net.ipv4.tcp_wmem'                => [ 4096, 65536, 16777216 ],

            # Don't cache ssthresh from previous connection
            'net.ipv4.tcp_no_metrics_save'     => 1,

            # Increase the number of ephemeral ports
            'net.ipv4.ip_local_port_range' =>  [ 1024, 65535 ],

            # Recommended to increase this for 1000 BT or higher
            'net.core.netdev_max_backlog'  =>  30000,

            # Increase the queue size of new TCP connections
            'net.core.somaxconn'           => 4096,
            'net.ipv4.tcp_max_syn_backlog' => 262144,
            'net.ipv4.tcp_max_tw_buckets'  => 360000,

            'net.ipv4.tcp_keepalive_time'      => 300,
            'net.ipv4.tcp_keepalive_intvl'     => 1,
            'net.ipv4.tcp_keepalive_probes'    => 2,
            
            'net.ipv6.route.max_size'          => 131072,

            # Mitigate side-channel from challenge acks, at least until most
            # public servers are on kernel 4.7+ or have a backported fix.
            # Refs:
            # CVE-2016-5696
            # http://www.cs.ucr.edu/~zhiyunq/pub/sec16_TCP_pure_offpath.pdf
            # http://git.kernel.org/cgit/linux/kernel/git/torvalds/linux.git/commit/?id=75ff39ccc1bd5d3c455b6822ab09e533c551f758
            'net.ipv4.tcp_challenge_ack_limit' => 987654321,
        },
        priority => 60,
    }

    # unprivileged bpf is a feature introduced in Linux 4.4: https://lwn.net/Articles/660331/
    # We don't need it and it widens the attacks surface for local privilege escalation
    # significantly, so we're disabling it by enabling kernel.unprivileged_bpf_disabled
    if (versioncmp($::kernelversion, '4.4') >= 0) {
        sysctl::parameters { 'disable_unprivileged_bpf':
            values => {
              'kernel.unprivileged_bpf_disabled' => '1',
            },
        }
    }

    # Up to Buster Debian disabled unprivileged user namespaces in the default kernel config
    # This changed in Bullseye mostly to allow Chromium and Firefox to setup sandboxing via namespaces
    # But for a server deployment like ours, we have no use for it and it widens the attack surface,
    # so we disable it. Apply this to kernels starting with 5.10 (where it was enabled in Debian)
    if (versioncmp($::kernelversion, '5.10') >= 0) {
        sysctl::parameters { 'disable_unprivileged_ns':
            values => {
              'kernel.unprivileged_userns_clone' => '0',
            },
        }
    }

    if $::virtual == 'kvm' {
        sysctl::parameters { 'avoid swap usage':
            values  => { 'vm.swappiness' => lookup('base::sysctl::swap_value', {'default_value' => 1}), },
        }

        sysctl::parameters { 'increase open files limit':
            values  => { 'fs.file-max' => 26384062, },
        }

        # Disabling transparent hugepages is strongly recommended
        # in http://redis.io/topics/latency.
        sysfs::parameters { 'disable_transparent_hugepages':
            values => { 'kernel/mm/transparent_hugepage/enabled' => 'never' },
        }

        # Background save may fail under low memory condition unless
        # vm.overcommit_memory is 1.
        sysctl::parameters { 'vm.overcommit_memory':
            values => { 'vm.overcommit_memory' => 1 },
        }
    }
}
