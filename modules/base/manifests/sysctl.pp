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

            # Increase the queue size of new TCP connections
            'net.core.somaxconn'               => 1024,
            'net.ipv4.tcp_max_syn_backlog'     => 4096,

            'net.ipv4.tcp_keepalive_time'      => 300,
            'net.ipv4.tcp_keepalive_intvl'     => 1,
            'net.ipv4.tcp_keepalive_probes'    => 2,

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

    if $::virtual == 'kvm' {
        sysctl::parameters { 'avoid swap usage':
            values  => { 'vm.swappiness' => hiera('base::sysctl::swap_value', 1), },
        }

        sysctl::parameters { 'increase open files limit':
            values  => { 'fs.file-max' => 26384062, },
        }
    }
}
