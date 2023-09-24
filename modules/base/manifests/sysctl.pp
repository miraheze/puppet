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
            'net.ipv4.ip_local_port_range'     =>  [ 1024, 65535 ],

            # Recommended to increase this for 1000 BT or higher
            'net.core.netdev_max_backlog'      =>  30000,

            # Increase the queue size of new TCP connections
            'net.core.somaxconn'               => 4096,
            'net.ipv4.tcp_max_syn_backlog'     => 262144,
            'net.ipv4.tcp_max_tw_buckets'      => 360000,

            # Swapping makes things too slow and should be done rarely
            # 0 = only swap in OOM conditions (it does NOT disable swap.)
            'vm.swappiness'                    => 0,
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
    if (versioncmp($facts['kernelversion'], '4.4') >= 0) {
        sysctl::parameters { 'disable_unprivileged_bpf':
            values => {
              'kernel.unprivileged_bpf_disabled' => '1',
            },
        }
    }

    if (versioncmp($facts['kernelversion'], '5.10') >= 0) {
        # Up to Buster Debian disabled unprivileged user namespaces in the default kernel config
        # This changed in Bullseye mostly to allow Chromium and Firefox to setup sandboxing via namespaces
        # But for a server deployment like ours, we have no use for it and it widens the attack surface,
        # so we disable it. Apply this to kernels starting with 5.10 (where it was enabled in Debian)
        sysctl::parameters { 'disable_unprivileged_ns':
            values => {
              'kernel.unprivileged_userns_clone' => '0',
            },
        }

        # Kernels prior to v5.10.54 had this value set to 3600 as a defense
        # mechanism against faulty middle boxes which do not support TCP
        # fast open. The value was changed to 0 in v5.10.54. Unfortunately,
        # we do have faulty middle boxes in our path and the new value of 0
        # results in our mail queues backing up, as connections to Google's
        # mail servers sometimes timeout.
        # https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/commit/?h=v5.10.96&id=164294d09c47b9a6c6160b08c43d74ae93c82758
        sysctl::parameters { 'fastopen':
            values   => { 'net.ipv4.tcp_fastopen_blackhole_timeout_sec' => 3600 },
        }
    }

    # The security fix for CVE-2019-11479 introduced a new sysctl setting which clamps
    # the lower value for the advertised MSS. The Linux patch retains the formerly
    # hardcoded default of 48 for backwards compatibility reasons. We're setting it to
    # 536 which is the minimum MTU for IPv4 minus the default headers (see RFC9293 3.7.1)
    # This should allow all legitimate traffic while avoiding the resource exhaustion.  
    # We also explicitly enable TCP selective acks.
    #
    # To prevent an attack whereby a user can force us to cache an MTU for a destination
    # lower than the smallest TCP packets allowed, we also set the minimum route pmtu
    # cache value to min MSS + 40 = 576 (T344829).
    sysctl::parameters{'tcp_min_snd_mss':
        values  => {
            'net.ipv4.route.min_pmtu'  => '576',
            'net.ipv4.tcp_min_snd_mss' => '536',
            'net.ipv4.tcp_sack'        => 1,
        },
    }

    if $facts['virtual'] == 'kvm' {
        sysctl::parameters { 'increase open files limit':
            values  => { 'fs.file-max' => 26384062, },
        }
    }
}
